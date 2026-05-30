"""Atomic version test: serial number should match baseline."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_FIELD_REASON = "{device} does not report serial_number in '{command}' output"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned version serial number baseline parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current version serial number state"
VALUE_MISMATCH = (
    "{device}'s version serial number has drifted - we expected "
    "'{expected_value}' but found '{current_value}' instead."
)
VALUE_MATCH = (
    "{device}'s current version serial number ({current_value}) matches "
    "baseline parameters ({expected_value})"
)


class VersionSerialNumberDeviceParameters(TypedDict):
    value: str


class VersionSerialNumberParameters(TypedDict):
    devices: dict[str, VersionSerialNumberDeviceParameters]


class VerifyVersionSerialNumber(LearningTestCase[VersionSerialNumberParameters]):
    """Value check for parsed version serial number."""

    DESCRIPTION = (
        "Validate that each device's version serial number remains aligned with "
        "the learned baseline."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show version` command is supported on applicable targets.\n"
        "- Learned version serial number baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show version` on each applicable device.\n"
        "- Parse the command output and extract `serial_number`.\n"
        "- Compare current value against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}: expected value={{ device_data.value }}\n"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when the current version serial number equals the learned baseline.\n"
        "- Fail on missing baseline/current state or value mismatch."
    )

    command = "show version"

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

    async def gather_state(self, context: Context) -> VersionSerialNumberParameters:
        devices: dict[str, VersionSerialNumberDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            value = parsed.get("serial_number")
            if value is None or str(value) == "":
                context.results.add_result(
                    ResultStatus.NOT_APPLICABLE,
                    MISSING_FIELD_REASON.format(
                        device=device.name, command=self.command
                    ),
                )
                continue
            devices[device.name] = {"value": str(value)}
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: VersionSerialNumberParameters,
        current: VersionSerialNumberParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                expected_value = expected["devices"][device.name]["value"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_BASELINE.format(device=device.name),
                )
                continue

            try:
                current_value = current["devices"][device.name]["value"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            if current_value != expected_value:
                context.results.add_result(
                    ResultStatus.FAILED,
                    VALUE_MISMATCH.format(
                        device=device.name,
                        expected_value=expected_value,
                        current_value=current_value,
                    ),
                )
                continue

            context.results.add_result(
                ResultStatus.PASSED,
                VALUE_MATCH.format(
                    device=device.name,
                    current_value=current_value,
                    expected_value=expected_value,
                ),
            )
