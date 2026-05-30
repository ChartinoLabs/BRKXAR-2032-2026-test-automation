"""Atomic BGP summary test: neighbor remote AS should match baseline."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned BGP summary neighbor remote AS baseline parameters"
)
MISSING_CURRENT_STATE = (
    "{device} is missing current BGP summary neighbor remote AS state"
)
MISSING_NEIGHBOR = (
    "{device}'s learned BGP neighbor '{neighbor}' is missing from current state."
)
VALUE_MISMATCH = (
    "{device}'s BGP neighbor '{neighbor}' remote AS has drifted - we expected "
    "'{expected_value}' but found '{current_value}' instead."
)
VALUES_MATCH = (
    "{device}'s current BGP summary neighbor remote AS values match baseline parameters"
)


class BgpSummaryNeighborRemoteAsDeviceParameters(TypedDict):
    values: dict[str, str]


class BgpSummaryNeighborRemoteAsParameters(TypedDict):
    devices: dict[str, BgpSummaryNeighborRemoteAsDeviceParameters]


class VerifyBgpSummaryNeighborRemoteAs(
    LearningTestCase[BgpSummaryNeighborRemoteAsParameters]
):
    """Value check for parsed BGP summary neighbor remote AS."""

    DESCRIPTION = (
        "Validate that each BGP neighbor's remote AS remains aligned with "
        "the learned baseline."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip bgp summary` command is supported on applicable targets.\n"
        "- Learned BGP summary neighbor remote AS baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show ip bgp summary` on each applicable device.\n"
        "- Parse the command output and extract `neighbors.*.remote_as`.\n"
        "- Compare current values against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for neighbor, val in device_data['values'].items() %}"
        "  - {{ neighbor }}: expected remote_as={{ val }}\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when each neighbor's remote AS matches the learned baseline.\n"
        "- Fail on missing baseline/current state, missing neighbors, or value mismatch."
    )

    command = "show ip bgp summary"

    async def check_command_support(self, context: Context) -> CommandSupportResult:
        applicable = []
        not_applicable: dict[str, str] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            if is_command_unsupported(result.output):
                not_applicable[device.name] = NOT_SUPPORTED_REASON.format(
                    command=self.command
                )
                continue
            applicable.append(device)
        return CommandSupportResult(
            applicable=applicable, not_applicable=not_applicable
        )

    async def gather_state(
        self, context: Context
    ) -> BgpSummaryNeighborRemoteAsParameters:
        devices: dict[str, BgpSummaryNeighborRemoteAsDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            parsed = next(iter(parsed["address_families"].values()))
            values: dict[str, str] = {}
            for neighbor, data in parsed["neighbors"].items():
                values[neighbor] = str(data["remote_as"])
            if not values:
                context.results.add_result(
                    ResultStatus.NOT_APPLICABLE,
                    f"{device.name}: No applicable data found for this field",
                )
                continue
            devices[device.name] = {"values": values}
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: BgpSummaryNeighborRemoteAsParameters,
        current: BgpSummaryNeighborRemoteAsParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                expected_values = expected["devices"][device.name]["values"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_BASELINE.format(device=device.name),
                )
                continue

            try:
                current_values = current["devices"][device.name]["values"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            has_failures = False
            for neighbor, expected_value in expected_values.items():
                current_value = current_values.get(neighbor)
                if current_value is None:
                    context.results.add_result(
                        ResultStatus.FAILED,
                        MISSING_NEIGHBOR.format(device=device.name, neighbor=neighbor),
                    )
                    has_failures = True
                    continue
                if current_value != expected_value:
                    context.results.add_result(
                        ResultStatus.FAILED,
                        VALUE_MISMATCH.format(
                            device=device.name,
                            neighbor=neighbor,
                            expected_value=expected_value,
                            current_value=current_value,
                        ),
                    )
                    has_failures = True

            if not has_failures:
                context.results.add_result(
                    ResultStatus.PASSED,
                    VALUES_MATCH.format(device=device.name),
                )
