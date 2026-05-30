"""Atomic interface brief test: learned status values must match baseline."""

from collections.abc import Iterable
from typing import Any, TypedDict, cast

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned interface brief status baseline parameters"
)
MISSING_CURRENT_STATE = (
    "{device} is missing current interface brief status state parameters"
)
MISSING_INTERFACE_FROM_CURRENT = (
    "{device}'s learned interface brief interface '{interface}' is missing from current "
    "status state."
)
STATUS_VALUE_MISMATCH = (
    "{device}'s interface brief status value for interface '{interface}' has drifted - "
    "we expected '{expected_status}' but found '{current_status}' instead."
)
STATUS_VALUES_MATCH = (
    "{device}'s current interface brief status values match baseline parameters"
)


class IpInterfaceBriefStatusDeviceParameters(TypedDict):
    status: dict[str, str]


class IpInterfaceBriefStatusParameters(TypedDict):
    devices: dict[str, IpInterfaceBriefStatusDeviceParameters]


class VerifyIpInterfaceBriefStatus(LearningTestCase[IpInterfaceBriefStatusParameters]):
    """Value check for learned interface status values."""

    DESCRIPTION = (
        "Validate that learned interface status values remain unchanged for each interface "
        "name."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip interface brief` command is supported on applicable targets.\n"
        "- Learned interface status baseline parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Execute `show ip interface brief` on each applicable device.\n"
        "- Parse output and extract status value by interface.\n"
        "- Compare current status values against learned baseline.\n"
        "\n"
        "Learned baseline targets:\n\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for interface, status_value in device_data.status.items() %}"
        "  - interface {{ interface }} expected status={{ status_value }}\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when each learned interface status value matches current state.\n"
        "- Fail on missing baseline/current state, missing interfaces, or value mismatch."
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

    async def gather_state(self, context: Context) -> IpInterfaceBriefStatusParameters:
        devices: dict[str, IpInterfaceBriefStatusDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            records = _parse_interface_records(
                output=result.output, device_os=device.os
            )
            _add_interface_brief_execution(
                context=context,
                device_name=device.name,
                output=result,
                records=records,
            )
            mapping = _interface_map(records)
            if not mapping:
                context.results.add_result(
                    ResultStatus.NOT_APPLICABLE,
                    f"{device.name}: No applicable data found for this field",
                )
                continue
            devices[device.name] = {
                "status": {
                    interface: values["status"] for interface, values in mapping.items()
                }
            }
        return {"devices": devices}

    async def compare_state(
        self,
        *,
        expected: IpInterfaceBriefStatusParameters,
        current: IpInterfaceBriefStatusParameters,
        context: Context,
    ) -> None:
        for device in context.targets:
            try:
                expected_values = expected["devices"][device.name]["status"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_LEARNED_BASELINE.format(device=device.name),
                )
                continue

            try:
                current_values = current["devices"][device.name]["status"]
            except KeyError:
                context.results.add_result(
                    ResultStatus.FAILED,
                    MISSING_CURRENT_STATE.format(device=device.name),
                )
                continue

            has_failures = False
            for interface, expected_status in expected_values.items():
                current_status = current_values.get(interface)
                if current_status is None:
                    context.results.add_result(
                        ResultStatus.FAILED,
                        MISSING_INTERFACE_FROM_CURRENT.format(
                            device=device.name,
                            interface=interface,
                        ),
                    )
                    has_failures = True
                    continue
                if current_status != expected_status:
                    context.results.add_result(
                        ResultStatus.FAILED,
                        STATUS_VALUE_MISMATCH.format(
                            device=device.name,
                            interface=interface,
                            expected_status=expected_status,
                            current_status=current_status,
                        ),
                    )
                    has_failures = True

            if has_failures:
                continue

            context.results.add_result(
                ResultStatus.PASSED,
                STATUS_VALUES_MATCH.format(device=device.name),
            )


def _parse_interface_records(*, output: str, device_os: str) -> list[dict[str, Any]]:
    parsed = _parse_with_os_fallback(output=output, device_os=device_os)
    return _as_records(parsed)


def _add_interface_brief_execution(
    *,
    context: Context,
    device_name: str,
    output: Any,
    records: list[dict[str, Any]],
) -> None:
    parsed_payload: dict[str, object] = {"records": records}
    context.results.add_command_execution(
        device=device_name,
        command="show ip interface brief",
        output=output,
        parsed=parsed_payload,
    )


def _interface_map(records: list[dict[str, Any]]) -> dict[str, dict[str, str]]:
    mapping: dict[str, dict[str, str]] = {}
    for record in records:
        interface = _pick_value(record, ["interface", "intf", "name", "port"])
        if not interface:
            continue
        mapping[interface] = {
            "ip": _pick_value(record, ["ip", "ip_address", "address", "ipv4"]),
            "status": _pick_value(
                record, ["status", "state", "link_status", "admin_status"]
            ),
            "protocol": _pick_value(
                record,
                [
                    "protocol",
                    "protocol_status",
                    "line_protocol",
                    "line_status",
                    "oper_status",
                ],
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
