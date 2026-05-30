"""Convergence gate: wait for OSPF neighbor adjacencies to reach expected state."""

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
MISSING_LEARNED_BASELINE = "{device} is missing learned OSPF neighbor gate parameters"
MISSING_CURRENT_STATE = "{device} is missing current OSPF neighbor state"
NEIGHBOR_NOT_CONVERGED = (
    "{device}'s OSPF neighbor '{neighbor}' on interface '{interface}' "
    "has not converged - expected state '{expected}' but found '{current}'."
)
NEIGHBOR_MISSING = (
    "{device}'s expected OSPF neighbor '{neighbor}' on interface '{interface}' "
    "has not yet appeared."
)
GATE_PASSED = "{device}'s OSPF neighbor adjacencies have converged to expected state"
GATE_TIMEOUT = (
    "{device}'s OSPF neighbor adjacencies did not converge within {timeout}s. "
    "Remaining issues: {issues}"
)


def _state_matches(expected: str, current: str) -> bool:
    """Match OSPF neighbor states with optional DR/BDR-agnostic comparison.

    OSPF DR election is non-preemptive — once a DR is elected on a segment
    it stays the DR until the adjacency drops, so the role designation
    (DR / BDR / DROther) for any given neighbor is inherently unstable
    across OSPF restarts. To let gate parameter files express
    "I just want this neighbor in FULL state, regardless of role", a value
    of "FULL" matches any of "FULL", "FULL/DR", "FULL/BDR", or
    "FULL/DROther". Values containing "/" are matched exactly (so plans
    that DO want to assert a specific role still can).
    """
    if "/" in expected:
        return current == expected
    return current == expected or current.startswith(f"{expected}/")


class OspfNeighborGateDeviceParameters(TypedDict):
    neighbors: dict[str, dict[str, str]]


class OspfNeighborGateParameters(TypedDict):
    timeout: int
    interval: int
    devices: dict[str, OspfNeighborGateDeviceParameters]


class GateOspfNeighborAdjacency(LearningTestCase[OspfNeighborGateParameters]):
    """Convergence gate that polls OSPF neighbors until adjacencies match expected state."""

    DESCRIPTION = (
        "Wait for OSPF neighbor adjacencies to converge to the expected "
        "post-change state before proceeding with verification tests."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip ospf neighbor` command is supported on applicable targets.\n"
        "- Learned OSPF neighbor gate parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Poll `show ip ospf neighbor` on each applicable device.\n"
        "- Parse output and compare neighbor adjacencies against expected state.\n"
        "- Repeat every {interval}s until all adjacencies match or {timeout}s elapses.\n"
        "\n"
        "Expected convergence targets:\n\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for interface, nbrs in device_data.neighbors.items() %}"
        "{% for neighbor_id, state in nbrs.items() %}"
        "  - {{ neighbor_id }} on {{ interface }}: expected state={{ state }}\n"
        "{% endfor %}"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when all OSPF neighbor adjacencies match expected state.\n"
        "- Fail if adjacencies do not converge within the configured timeout."
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

    async def gather_state(self, context: Context) -> OspfNeighborGateParameters:
        devices: dict[str, OspfNeighborGateDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command, use_cache=False)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            neighbors: dict[str, dict[str, str]] = {}
            for interface, nbrs in parsed["neighbors"].items():
                interface_neighbors: dict[str, str] = {}
                for neighbor_id, data in nbrs.items():
                    state = str(data["state"])
                    role = data.get("role")
                    interface_neighbors[neighbor_id] = (
                        f"{state}/{role}" if role else state
                    )
                if interface_neighbors:
                    neighbors[interface] = interface_neighbors
            devices[device.name] = {"neighbors": neighbors}
        return {
            "timeout": DEFAULT_TIMEOUT,
            "interval": DEFAULT_INTERVAL,
            "devices": devices,
        }

    async def compare_state(
        self,
        *,
        expected: OspfNeighborGateParameters,
        current: OspfNeighborGateParameters,
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
    expected: OspfNeighborGateParameters,
    current: OspfNeighborGateParameters,
) -> dict[str, list[str]]:
    """Return per-device issues. Empty dict means converged."""
    issues: dict[str, list[str]] = {}
    for device_name, expected_device in expected["devices"].items():
        current_device = current.get("devices", {}).get(device_name)
        if current_device is None:
            issues[device_name] = [MISSING_CURRENT_STATE.format(device=device_name)]
            continue

        device_issues: list[str] = []
        current_neighbors = current_device.get("neighbors", {})
        for interface, expected_nbrs in expected_device["neighbors"].items():
            current_nbrs = current_neighbors.get(interface, {})
            for neighbor_id, expected_state in expected_nbrs.items():
                current_state = current_nbrs.get(neighbor_id)
                if current_state is None:
                    device_issues.append(
                        NEIGHBOR_MISSING.format(
                            device=device_name,
                            interface=interface,
                            neighbor=neighbor_id,
                        )
                    )
                elif not _state_matches(expected_state, current_state):
                    device_issues.append(
                        NEIGHBOR_NOT_CONVERGED.format(
                            device=device_name,
                            interface=interface,
                            neighbor=neighbor_id,
                            expected=expected_state,
                            current=current_state,
                        )
                    )
        if device_issues:
            issues[device_name] = device_issues
    return issues
