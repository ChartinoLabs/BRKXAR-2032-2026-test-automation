"""Atomic OSPF neighbor test: address should match baseline."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned OSPF neighbor address baseline parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current OSPF neighbor address state"
MISSING_NEIGHBOR = (
    "{device}'s learned OSPF neighbor '{neighbor}' on interface '{interface}' "
    "is missing from current state."
)
VALUE_MISMATCH = (
    "{device}'s OSPF neighbor '{neighbor}' on interface '{interface}' "
    "address has drifted - we expected '{expected_value}' but found "
    "'{current_value}' instead."
)
VALUES_MATCH = (
    "{device}'s current OSPF neighbor address values match baseline parameters"
)


class OspfNeighborAddressDeviceParameters(TypedDict):
    values: dict[str, dict[str, str]]


class OspfNeighborAddressParameters(TypedDict):
    devices: dict[str, OspfNeighborAddressDeviceParameters]


class VerifyOspfNeighborAddress(LearningTestCase[OspfNeighborAddressParameters]):
    """Value check for parsed OSPF neighbor address."""

    DESCRIPTION = (
        "Validate that each OSPF neighbor's address remains aligned with "
        "the learned baseline."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip ospf neighbor` command is supported on applicable targets.\n"
        "- Learned OSPF neighbor address baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show ip ospf neighbor` on each applicable device.\n"
        "- Parse the command output and extract `neighbors.*.*` address.\n"
        "- Compare current values against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for key, val in device_data['values'].items() %}"
        "  - {{ key }}: expected address={{ val }}\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when each neighbor's address matches the learned baseline.\n"
        "- Fail on missing baseline/current state, missing neighbors, or value mismatch."
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

    async def gather_state(self, context: Context) -> OspfNeighborAddressParameters:
        devices: dict[str, OspfNeighborAddressDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            values: dict[str, dict[str, str]] = {}
            for interface, neighbors in parsed["neighbors"].items():
                for neighbor_id, data in neighbors.items():
                    value = str(data["address"])
                    if not value:
                        continue
                    values.setdefault(interface, {})[neighbor_id] = value
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
        expected: OspfNeighborAddressParameters,
        current: OspfNeighborAddressParameters,
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
            for interface, neighbors in expected_values.items():
                current_interface = current_values.get(interface)
                if current_interface is None:
                    for neighbor in neighbors:
                        context.results.add_result(
                            ResultStatus.FAILED,
                            MISSING_NEIGHBOR.format(
                                device=device.name,
                                interface=interface,
                                neighbor=neighbor,
                            ),
                        )
                    has_failures = True
                    continue
                for neighbor, expected_value in neighbors.items():
                    current_value = current_interface.get(neighbor)
                    if current_value is None:
                        context.results.add_result(
                            ResultStatus.FAILED,
                            MISSING_NEIGHBOR.format(
                                device=device.name,
                                interface=interface,
                                neighbor=neighbor,
                            ),
                        )
                        has_failures = True
                        continue
                    if current_value != expected_value:
                        context.results.add_result(
                            ResultStatus.FAILED,
                            VALUE_MISMATCH.format(
                                device=device.name,
                                interface=interface,
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
