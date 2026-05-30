"""Action job: administratively shut down selected interfaces."""

import asyncio
from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_PARAMETERS = "{device} is missing learned interface parameters"
MISSING_CURRENT_STATE = "{device} is missing current interface state"
PRECONDITION_FAILED = (
    "{device}'s interface '{interface}' is not currently up "
    "(status='{status}', protocol='{protocol}') - cannot shut down"
)
SHUTDOWN_FAILED = (
    "{device}'s interface '{interface}' is still up after shutdown (status='{status}')"
)
SHUTDOWN_CONFIRMED = "{device}'s interface '{interface}' is now administratively down"
MISSING_INTERFACE = "{device}'s interface '{interface}' is missing from current state"

_POLL_INTERVAL_SECONDS = 2
_MAX_POLL_ATTEMPTS = 5


class InterfaceCandidate(TypedDict):
    description: str
    status: str
    protocol: str


class InterfaceAdminDownDeviceParameters(TypedDict):
    interfaces: dict[str, InterfaceCandidate]


class InterfaceAdminDownParameters(TypedDict):
    devices: dict[str, InterfaceAdminDownDeviceParameters]


class ChangeInterfaceAdminDown(LearningTestCase[InterfaceAdminDownParameters]):
    """Administratively shut down selected interfaces and verify the change."""

    DESCRIPTION = (
        "Administratively shut down selected interfaces on target devices "
        "and verify each interface transitions to 'administratively down'."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip interface brief` command is supported on applicable targets.\n"
        "- Selected interfaces are currently in an 'up' state."
    )
    PROCEDURE = (
        "- Execute `show ip interface brief` on each applicable device.\n"
        "- Verify selected interfaces are currently up (precondition).\n"
        "- Send `interface <name>` / `shutdown` configuration commands.\n"
        "- Re-check interface status and confirm 'administratively down'.\n"
        "\n"
        "Target interfaces:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for intf, info in device_data.interfaces.items() %}"
        "  - {{ intf }} ({{ info.description or 'no description' }})\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when every selected interface is confirmed administratively down.\n"
        "- Fail if a precondition check fails or the interface remains up after shutdown."
    )

    show_command = "show ip interface brief"

    async def check_command_support(self, context: Context) -> CommandSupportResult:
        applicable = []
        not_applicable: dict[str, str] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.show_command)
            if is_command_unsupported(result.output):
                not_applicable[device.name] = NOT_SUPPORTED_REASON.format(
                    command=self.show_command
                )
                continue
            applicable.append(device)
        return CommandSupportResult(
            applicable=applicable, not_applicable=not_applicable
        )

    async def gather_state(self, context: Context) -> InterfaceAdminDownParameters:
        devices: dict[str, InterfaceAdminDownDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(
                device, self.show_command, bust_cache=True
            )
            brief = mn.parse(
                os=device.os, command=self.show_command, output=result.output
            )
            context.results.add_command_execution(
                device=device.name,
                command=self.show_command,
                output=result,
                parsed=brief,
            )

            # Collect interfaces that are currently up as candidates.
            # Use show interfaces for descriptions.
            desc_result = await context.broker.execute(
                device, "show interfaces", bust_cache=True
            )
            desc_parsed = mn.parse(
                os=device.os, command="show interfaces", output=desc_result.output
            )

            interfaces: dict[str, InterfaceCandidate] = {}
            for intf_name, intf_data in brief["interfaces"].items():
                if intf_data["status"] == "up":
                    description = (
                        desc_parsed["interfaces"]
                        .get(intf_name, {})
                        .get("description", "")
                    )
                    interfaces[intf_name] = {
                        "description": description,
                        "status": intf_data["status"],
                        "protocol": intf_data["protocol"],
                    }
            devices[device.name] = {"interfaces": interfaces}
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: InterfaceAdminDownParameters,
        current: InterfaceAdminDownParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                target_intfs = expected["devices"][device.name]["interfaces"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_PARAMETERS.format(device=device.name),
                )
                continue

            try:
                current_intfs = current["devices"][device.name]["interfaces"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            # Validate preconditions — each target interface should be up now.
            preconditions_met = True
            for intf_name in target_intfs:
                intf_state = current_intfs.get(intf_name)
                if intf_state is None:
                    # Interface not in the "up" candidate set; check if it
                    # exists at all by re-reading full brief output.
                    context.results.add_result(
                        ResultStatus.FAILED,
                        MISSING_INTERFACE.format(
                            device=device.name, interface=intf_name
                        ),
                    )
                    preconditions_met = False

            if not preconditions_met:
                continue

            # Execute shutdown on each target interface.
            config_lines = []
            for intf_name in target_intfs:
                config_lines.append(f"interface {intf_name}")
                config_lines.append("shutdown")
            config = "\n".join(config_lines)
            await context.broker.edit(device, config)

            # Poll until all target interfaces are admin down.
            remaining = set(target_intfs)
            verify_parsed = None
            for attempt in range(_MAX_POLL_ATTEMPTS):
                await asyncio.sleep(_POLL_INTERVAL_SECONDS)
                verify_result = await context.broker.execute(
                    device, self.show_command, bust_cache=True
                )
                verify_parsed = mn.parse(
                    os=device.os,
                    command=self.show_command,
                    output=verify_result.output,
                )
                still_pending = set()
                for intf_name in remaining:
                    post_data = verify_parsed["interfaces"].get(intf_name, {})
                    if post_data.get("status", "") != "administratively down":
                        still_pending.add(intf_name)
                remaining = still_pending
                if not remaining:
                    break

            # Record final command execution for the last poll.
            if verify_parsed is not None:
                context.results.add_command_execution(
                    device=device.name,
                    command=self.show_command,
                    output=verify_result,
                    parsed=verify_parsed,
                )

            # Report results for each interface.
            for intf_name in target_intfs:
                if intf_name not in remaining:
                    context.results.add_result(
                        ResultStatus.PASSED,
                        SHUTDOWN_CONFIRMED.format(
                            device=device.name, interface=intf_name
                        ),
                    )
                else:
                    post_data = (
                        verify_parsed["interfaces"].get(intf_name, {})
                        if verify_parsed
                        else {}
                    )
                    context.results.add_result(
                        ResultStatus.FAILED,
                        SHUTDOWN_FAILED.format(
                            device=device.name,
                            interface=intf_name,
                            status=post_data.get("status", "unknown"),
                        ),
                    )
