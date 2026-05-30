"""Atomic OSPF neighbor test: learned neighbors should still exist."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned OSPF neighbor baseline parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current OSPF neighbor state"
MISSING_NEIGHBOR = (
    "{device}'s learned OSPF neighbor '{neighbor}' on interface '{interface}' "
    "is missing from current state."
)
ALL_NEIGHBORS_PRESENT = (
    "{device}'s current OSPF neighbor set matches baseline parameters"
)


class OspfNeighborExistenceDeviceParameters(TypedDict):
    adjacencies: dict[str, dict[str, str]]


class OspfNeighborExistenceParameters(TypedDict):
    devices: dict[str, OspfNeighborExistenceDeviceParameters]


class VerifyOspfNeighborExistence(LearningTestCase[OspfNeighborExistenceParameters]):
    """Existence check for learned OSPF neighbors per interface."""

    DESCRIPTION = (
        "Validate that every learned OSPF neighbor still exists on its "
        "expected interface."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip ospf neighbor` command is supported on applicable targets.\n"
        "- Learned OSPF neighbor baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show ip ospf neighbor` on each applicable device.\n"
        "- Parse the command output and collect interface/neighbor pairs.\n"
        "- Compare current pairs against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for pair in device_data.adjacencies %}"
        "  - neighbor {{ pair.1 }} on {{ pair.0 }} must exist\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when every learned OSPF neighbor is present on its interface.\n"
        "- Fail on missing baseline/current state or missing adjacencies."
    )

    command = "show ip ospf neighbor"

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

    async def gather_state(self, context: Context) -> OspfNeighborExistenceParameters:
        devices: dict[str, OspfNeighborExistenceDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            adjacencies: dict[str, dict[str, str]] = {}
            for interface, neighbors in parsed["neighbors"].items():
                for neighbor_id in neighbors:
                    adjacencies.setdefault(interface, {})[neighbor_id] = "__exists__"
            devices[device.name] = {"adjacencies": adjacencies}
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: OspfNeighborExistenceParameters,
        current: OspfNeighborExistenceParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                expected_adjs = expected["devices"][device.name]["adjacencies"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_BASELINE.format(device=device.name),
                )
                continue

            try:
                current_adjs = current["devices"][device.name]["adjacencies"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            missing = False
            for interface, neighbors in expected_adjs.items():
                for neighbor_id in neighbors:
                    if neighbor_id not in current_adjs.get(interface, {}):
                        context.results.add_result(
                            ResultStatus.FAILED,
                            MISSING_NEIGHBOR.format(
                                device=device.name,
                                interface=interface,
                                neighbor=neighbor_id,
                            ),
                        )
                        missing = True
            if missing:
                continue

            context.results.add_result(
                ResultStatus.PASSED,
                ALL_NEIGHBORS_PRESENT.format(device=device.name),
            )
