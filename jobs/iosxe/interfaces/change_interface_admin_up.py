"""Action job: administratively bring up selected interfaces."""

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
    "{device}'s interface '{interface}' is not currently admin down "
    "(status='{status}') - cannot bring up"
)
BRING_UP_FAILED = (
    "{device}'s interface '{interface}' did not come up after no shutdown "
    "(status='{status}', protocol='{protocol}')"
)
BRING_UP_CONFIRMED = "{device}'s interface '{interface}' is now up/up"
MISSING_INTERFACE = "{device}'s interface '{interface}' is missing from current state"

_POLL_INTERVAL_SECONDS = 5
_MAX_POLL_ATTEMPTS = 12


class InterfaceCandidate(TypedDict):
    description: str
    status: str
    protocol: str


class InterfaceAdminUpDeviceParameters(TypedDict):
    interfaces: dict[str, InterfaceCandidate]


class InterfaceAdminUpParameters(TypedDict):
    devices: dict[str, InterfaceAdminUpDeviceParameters]


class ChangeInterfaceAdminUp(LearningTestCase[InterfaceAdminUpParameters]):
    """Administratively bring up selected interfaces and verify the change."""

    DESCRIPTION = (
        "Remove administrative shutdown from selected interfaces on target "
        "devices and verify each interface transitions to up/up."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip interface brief` command is supported on applicable targets.\n"
        "- Selected interfaces are currently in an 'administratively down' state."
    )
    PROCEDURE = (
        "- Execute `show ip interface brief` on each applicable device.\n"
        "- Verify selected interfaces are currently admin down (precondition).\n"
        "- Send `interface <name>` / `no shutdown` configuration commands.\n"
        "- Re-check interface status and confirm up/up.\n"
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
        "- Pass when every selected interface is confirmed up/up.\n"
        "- Fail if a precondition check fails or the interface does not come up."
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

    async def gather_state(self, context: Context) -> InterfaceAdminUpParameters:
        devices: dict[str, InterfaceAdminUpDeviceParameters] = {}
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

            # Collect interfaces that are currently admin down as candidates.
            desc_result = await context.broker.execute(
                device, "show interfaces", bust_cache=True
            )
            desc_parsed = mn.parse(
                os=device.os, command="show interfaces", output=desc_result.output
            )

            interfaces: dict[str, InterfaceCandidate] = {}
            for intf_name, intf_data in brief["interfaces"].items():
                if intf_data["status"] == "administratively down":
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
        expected: InterfaceAdminUpParameters,
        current: InterfaceAdminUpParameters,
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

            # Validate preconditions — each target interface should be admin down.
            preconditions_met = True
            for intf_name in target_intfs:
                if intf_name not in current_intfs:
                    # Not in the admin-down candidate set — check raw state.
                    context.results.add_result(
                        ResultStatus.FAILED,
                        MISSING_INTERFACE.format(
                            device=device.name, interface=intf_name
                        ),
                    )
                    preconditions_met = False

            if not preconditions_met:
                continue

            # Execute no shutdown on each target interface.
            config_lines = []
            for intf_name in target_intfs:
                config_lines.append(f"interface {intf_name}")
                config_lines.append("no shutdown")
            config = "\n".join(config_lines)
            await context.broker.edit(device, config)

            # Poll until all target interfaces are up/up.
            # Physical interfaces can take time to negotiate link parameters.
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
                    if not (
                        post_data.get("status", "") == "up"
                        and post_data.get("protocol", "") == "up"
                    ):
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
                        BRING_UP_CONFIRMED.format(
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
                        BRING_UP_FAILED.format(
                            device=device.name,
                            interface=intf_name,
                            status=post_data.get("status", "unknown"),
                            protocol=post_data.get("protocol", "unknown"),
                        ),
                    )
