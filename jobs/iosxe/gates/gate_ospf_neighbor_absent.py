"""Convergence gate: wait for specified OSPF neighbor adjacencies to disappear."""

import asyncio
import time
from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

DEFAULT_TIMEOUT = 60
DEFAULT_INTERVAL = 5

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = (
    "{device} is missing learned OSPF neighbor absent gate parameters"
)
MISSING_CURRENT_STATE = "{device} is missing current OSPF neighbor state"
NEIGHBOR_STILL_PRESENT = (
    "{device}'s OSPF neighbor '{neighbor}' on interface '{interface}' "
    "is still present but should have been removed."
)
GATE_PASSED = "{device}'s expected OSPF neighbor removals have completed"
GATE_TIMEOUT = (
    "{device}'s OSPF neighbor removals did not complete within {timeout}s. "
    "Remaining issues: {issues}"
)


class OspfNeighborAbsentDeviceParameters(TypedDict):
    absent: dict[str, list[str]]


class OspfNeighborAbsentParameters(TypedDict):
    timeout: int
    interval: int
    devices: dict[str, OspfNeighborAbsentDeviceParameters]


class GateOspfNeighborAbsent(LearningTestCase[OspfNeighborAbsentParameters]):
    """Convergence gate that polls OSPF neighbors until specified adjacencies are gone."""

    DESCRIPTION = (
        "Wait for specified OSPF neighbor adjacencies to be removed "
        "before proceeding with verification tests."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip ospf neighbor` command is supported on applicable targets.\n"
        "- Learned OSPF neighbor absent gate parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Poll `show ip ospf neighbor` on each applicable device.\n"
        "- Parse output and check that specified adjacencies no longer exist.\n"
        "- Repeat every {interval}s until all specified adjacencies are gone "
        "or {timeout}s elapses.\n"
        "\n"
        "Expected removals:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for interface, neighbor_ids in device_data.absent.items() %}"
        "{% for neighbor_id in neighbor_ids %}"
        "  - neighbor {{ neighbor_id }} on {{ interface }} must be absent\n"
        "{% endfor %}"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when all specified OSPF adjacencies have been removed.\n"
        "- Fail if any specified adjacency remains after the configured timeout."
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

    async def gather_state(self, context: Context) -> OspfNeighborAbsentParameters:
        devices: dict[str, OspfNeighborAbsentDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command, use_cache=False)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            # Gather all current adjacencies; the test author removes entries
            # that should persist and keeps only those expected to disappear.
            absent: dict[str, list[str]] = {}
            for interface, nbrs in parsed["neighbors"].items():
                neighbor_ids = list(nbrs.keys())
                if neighbor_ids:
                    absent[interface] = neighbor_ids
            devices[device.name] = {"absent": absent}
        return {
            "timeout": DEFAULT_TIMEOUT,
            "interval": DEFAULT_INTERVAL,
            "devices": devices,
        }

    async def compare_state(
        self,
        *,
        expected: OspfNeighborAbsentParameters,
        current: OspfNeighborAbsentParameters,
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
    expected: OspfNeighborAbsentParameters,
    current: OspfNeighborAbsentParameters,
) -> dict[str, list[str]]:
    """Return per-device issues. Empty dict means all specified neighbors are gone."""
    issues: dict[str, list[str]] = {}
    for device_name, expected_device in expected["devices"].items():
        current_device = current.get("devices", {}).get(device_name)
        if current_device is None:
            # No current state means no neighbors — absent check passes
            continue

        current_neighbors = current_device.get("absent", {})

        device_issues: list[str] = []
        for interface, expected_ids in expected_device["absent"].items():
            current_ids = set(current_neighbors.get(interface, []))
            for neighbor_id in expected_ids:
                if neighbor_id in current_ids:
                    device_issues.append(
                        NEIGHBOR_STILL_PRESENT.format(
                            device=device_name,
                            interface=interface,
                            neighbor=neighbor_id,
                        )
                    )
        if device_issues:
            issues[device_name] = device_issues
    return issues
