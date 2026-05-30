"""Convergence gate: wait for interface status to match expected state."""

import asyncio
import time
from collections.abc import Iterable
from typing import Any, TypedDict, cast

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

DEFAULT_TIMEOUT = 30
DEFAULT_INTERVAL = 5

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned interface status gate parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current interface status state"
STATUS_MISMATCH = (
    "{device}'s interface '{interface}' status has not converged - "
    "expected '{expected}' but found '{current}'."
)
GATE_PASSED = "{device}'s interface status has converged to expected state"
GATE_TIMEOUT = (
    "{device}'s interface status did not converge within {timeout}s. "
    "Remaining issues: {issues}"
)


class InterfaceGateDeviceParameters(TypedDict):
    status: dict[str, str]


class InterfaceGateParameters(TypedDict):
    timeout: int
    interval: int
    devices: dict[str, InterfaceGateDeviceParameters]


class GateInterfaceStatus(LearningTestCase[InterfaceGateParameters]):
    """Convergence gate that polls interface status until it matches expected state."""

    DESCRIPTION = (
        "Wait for interface status values to converge to the expected "
        "post-change state before proceeding with verification tests."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip interface brief` command is supported on applicable targets.\n"
        "- Learned interface status gate parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Poll `show ip interface brief` on each applicable device.\n"
        "- Parse output and compare interface status values against expected state.\n"
        "- Repeat every {interval}s until all values match or {timeout}s elapses.\n"
        "\n"
        "Expected convergence targets:\n\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for interface, status in device_data.status.items() %}"
        "  - {{ interface }}: expected status={{ status }}\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when all interface status values match expected state.\n"
        "- Fail if status values do not converge within the configured timeout."
    )

    command = "show ip interface brief"

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

    async def gather_state(self, context: Context) -> InterfaceGateParameters:
        devices: dict[str, InterfaceGateDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command, use_cache=False)
            records = _parse_interface_records(
                output=result.output, device_os=device.os
            )
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed={"records": records},
            )
            mapping = _interface_map(records)
            devices[device.name] = {
                "status": {
                    interface: values["status"] for interface, values in mapping.items()
                }
            }
        return {
            "timeout": DEFAULT_TIMEOUT,
            "interval": DEFAULT_INTERVAL,
            "devices": devices,
        }

    async def compare_state(
        self,
        *,
        expected: InterfaceGateParameters,
        current: InterfaceGateParameters,
        context: Context,
    ) -> None:
        timeout = expected.get("timeout", DEFAULT_TIMEOUT)
        interval = expected.get("interval", DEFAULT_INTERVAL)
        deadline = time.monotonic() + timeout

        while True:
            issues = _check_convergence(expected, current)
            if not issues:
                for device_name in expected["devices"]:
                    context.results.add_result(
                        ResultStatus.PASSED,
                        GATE_PASSED.format(device=device_name),
                    )
                return

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                for device_name, device_issues in issues.items():
                    context.results.add_result(
                        ResultStatus.FAILED,
                        GATE_TIMEOUT.format(
                            device=device_name,
                            timeout=timeout,
                            issues="; ".join(device_issues),
                        ),
                    )
                return

            await asyncio.sleep(min(interval, remaining))
            current = await self.gather_state(context)


def _check_convergence(
    expected: InterfaceGateParameters,
    current: InterfaceGateParameters,
) -> dict[str, list[str]]:
    """Return per-device issues. Empty dict means converged."""
    issues: dict[str, list[str]] = {}
    for device_name, expected_device in expected["devices"].items():
        current_device = current.get("devices", {}).get(device_name)
        if current_device is None:
            issues[device_name] = [MISSING_CURRENT_STATE.format(device=device_name)]
            continue

        device_issues: list[str] = []
        for interface, expected_status in expected_device["status"].items():
            current_status = current_device["status"].get(interface, "")
            if current_status != expected_status:
                device_issues.append(
                    STATUS_MISMATCH.format(
                        device=device_name,
                        interface=interface,
                        expected=expected_status,
                        current=current_status,
                    )
                )
        if device_issues:
            issues[device_name] = device_issues
    return issues


def _parse_interface_records(*, output: str, device_os: str) -> list[dict[str, Any]]:
    parsed = _parse_with_os_fallback(output=output, device_os=device_os)
    return _as_records(parsed)


def _interface_map(records: list[dict[str, Any]]) -> dict[str, dict[str, str]]:
    mapping: dict[str, dict[str, str]] = {}
    for record in records:
        interface = _pick_value(record, ["interface", "intf", "name", "port"])
        if not interface:
            continue
        mapping[interface] = {
            "status": _pick_value(
                record, ["status", "state", "link_status", "admin_status"]
            ),
        }
    return mapping


def _parse_with_os_fallback(*, output: str, device_os: str) -> object:
    os_candidates = [device_os]
    if device_os == "ios":
        os_candidates.append("iosxe")

    for os_name in os_candidates:
        try:
            return mn.parse(
                os=os_name,
                command="show ip interface brief",
                output=output,
            )
        except Exception:  # noqa: BLE001
            continue

    return []


def _as_records(parsed: object) -> list[dict[str, Any]]:
    if isinstance(parsed, dict):
        parsed_dict = cast(dict[str, Any], parsed)
        interfaces = parsed_dict.get("interfaces")
        if isinstance(interfaces, dict):
            return _records_from_interfaces(interfaces)

        vrfs = parsed_dict.get("vrfs")
        if isinstance(vrfs, dict):
            return _records_from_vrfs(vrfs)

        raw_records = [parsed_dict]
    elif isinstance(parsed, list):
        raw_records = parsed
    else:
        return []

    records: list[dict[str, Any]] = []
    for record in raw_records:
        if isinstance(record, dict):
            records.append(cast(dict[str, Any], record))
    return records


def _records_from_interfaces(interfaces: dict[str, object]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for interface, entry in interfaces.items():
        if not isinstance(entry, dict):
            continue
        record = cast(dict[str, Any], entry).copy()
        record["interface"] = interface
        records.append(record)
    return records


def _records_from_vrfs(vrfs: dict[str, object]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for vrf_name, vrf in vrfs.items():
        if not isinstance(vrf, dict):
            continue
        vrf_dict = cast(dict[str, Any], vrf)
        interfaces = vrf_dict.get("interfaces")
        if not isinstance(interfaces, dict):
            continue
        for record in _records_from_interfaces(interfaces):
            record["vrf"] = vrf_name
            records.append(record)
    return records


def _pick_value(record: dict[str, Any], candidates: Iterable[str]) -> str:
    lowered = {str(key).lower(): value for key, value in record.items()}
    for key in candidates:
        value = lowered.get(key.lower())
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return ""
