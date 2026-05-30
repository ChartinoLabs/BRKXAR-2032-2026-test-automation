"""Atomic BGP summary test: learned BGP neighbors should still exist."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned BGP summary neighbor baseline parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current BGP summary neighbor state"
MISSING_NEIGHBOR = (
    "{device}'s learned BGP neighbor '{neighbor}' is missing from current state."
)
ALL_NEIGHBORS_PRESENT = (
    "{device}'s current BGP neighbor set matches baseline parameters"
)


class BgpSummaryNeighborExistenceDeviceParameters(TypedDict):
    neighbors: dict[str, str]


class BgpSummaryNeighborExistenceParameters(TypedDict):
    devices: dict[str, BgpSummaryNeighborExistenceDeviceParameters]


class VerifyBgpSummaryNeighborExistence(
    LearningTestCase[BgpSummaryNeighborExistenceParameters]
):
    """Existence check for learned BGP summary neighbors."""

    DESCRIPTION = (
        "Validate that every learned BGP neighbor still exists in current "
        "BGP summary state."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip bgp summary` command is supported on applicable targets.\n"
        "- Learned BGP summary neighbor baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show ip bgp summary` on each applicable device.\n"
        "- Parse the command output and collect current neighbor addresses.\n"
        "- Compare current neighbor set against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for neighbor in device_data.neighbors %}"
        "  - neighbor {{ neighbor }} must exist\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when every learned BGP neighbor is present in current state.\n"
        "- Fail on missing baseline/current state or missing learned neighbors."
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
    ) -> BgpSummaryNeighborExistenceParameters:
        devices: dict[str, BgpSummaryNeighborExistenceDeviceParameters] = {}
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
            neighbors = {n: "__exists__" for n in sorted(parsed["neighbors"].keys())}
            devices[device.name] = {"neighbors": neighbors}
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: BgpSummaryNeighborExistenceParameters,
        current: BgpSummaryNeighborExistenceParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                expected_neighbors = expected["devices"][device.name]["neighbors"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_BASELINE.format(device=device.name),
                )
                continue

            try:
                current_neighbors = current["devices"][device.name]["neighbors"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            missing = [n for n in expected_neighbors if n not in current_neighbors]
            if missing:
                for neighbor in missing:
                    context.results.add_result(
                        ResultStatus.FAILED,
                        MISSING_NEIGHBOR.format(device=device.name, neighbor=neighbor),
                    )
                continue

            context.results.add_result(
                ResultStatus.PASSED,
                ALL_NEIGHBORS_PRESENT.format(device=device.name),
            )
