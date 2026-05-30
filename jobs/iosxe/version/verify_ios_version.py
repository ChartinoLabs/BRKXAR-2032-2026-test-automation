"""Atomic version test: IOS version should match baseline."""

from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_FIELD_REASON = "{device} does not report version in '{command}' output"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned version IOS version baseline parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current version IOS version state"
VALUE_MISMATCH = (
    "{device}'s version IOS version has drifted - we expected "
    "'{expected_value}' but found '{current_value}' instead."
)
VALUE_MATCH = (
    "{device}'s current version IOS version ({current_value}) matches "
    "baseline parameters ({expected_value})"
)


class VersionIosVersionDeviceParameters(TypedDict):
    value: str


class VersionIosVersionParameters(TypedDict):
    devices: dict[str, VersionIosVersionDeviceParameters]


class VerifyVersionIosVersion(LearningTestCase[VersionIosVersionParameters]):
    """Value check for parsed version IOS version."""

    DESCRIPTION = (
        "Validate that each device's version IOS version remains aligned with "
        "the learned baseline."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show version` command is supported on applicable targets.\n"
        "- Learned version IOS version baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show version` on each applicable device.\n"
        "- Parse the command output and extract `version`.\n"
        "- Compare current value against the learned baseline.\n"
        "\n"
        "Learned baseline targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}: expected value={{ device_data.value }}\n"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when the current version IOS version equals the learned baseline.\n"
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

    async def gather_state(self, context: Context) -> VersionIosVersionParameters:
        devices: dict[str, VersionIosVersionDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            value = parsed.get("version")
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
        expected: VersionIosVersionParameters,
        current: VersionIosVersionParameters,
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
