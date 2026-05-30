"""Convergence gate: wait for BGP peers to reach expected state."""

import asyncio
import time
from typing import TypedDict

import muninn

from huginn import CommandSupportResult, Context, LearningTestCase, ResultStatus
from huginn.utils.commands import is_command_unsupported

mn = muninn.Muninn()
mn.load_builtin_parsers()

DEFAULT_TIMEOUT = 90
DEFAULT_INTERVAL = 5

NOT_SUPPORTED_REASON = "Device does not support '{command}'"
MISSING_LEARNED_BASELINE = "{device} is missing learned BGP peering gate parameters"
MISSING_CURRENT_STATE = "{device} is missing current BGP summary state"
PEER_NOT_ESTABLISHED = (
    "{device}'s BGP peer '{neighbor}' has not reached established state - "
    "currently '{current}'."
)
PEER_STATE_MISMATCH = (
    "{device}'s BGP peer '{neighbor}' has not converged - "
    "expected '{expected}' but found '{current}'."
)
GATE_PASSED = "{device}'s BGP peering has converged to expected state"
GATE_TIMEOUT = (
    "{device}'s BGP peering did not converge within {timeout}s. "
    "Remaining issues: {issues}"
)


class BgpPeeringGateDeviceParameters(TypedDict):
    neighbors: dict[str, str]


class BgpPeeringGateParameters(TypedDict):
    timeout: int
    interval: int
    devices: dict[str, BgpPeeringGateDeviceParameters]


class GateBgpPeeringStatus(LearningTestCase[BgpPeeringGateParameters]):
    """Convergence gate that polls BGP summary until peers match expected state."""

    DESCRIPTION = (
        "Wait for BGP peering sessions to converge to the expected "
        "post-change state before proceeding with verification tests."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show ip bgp summary` command is supported on applicable targets.\n"
        "- Learned BGP peering gate parameters are available for testing mode."
    )
    PROCEDURE = (
        "- Poll `show ip bgp summary` on each applicable device.\n"
        "- Parse output and compare peer states against expected state.\n"
        "- For peers expected to be established (numeric prefix count), "
        "check that current state is also numeric.\n"
        "- For peers expected to be in a specific state, check exact match.\n"
        "- Repeat every {interval}s until all peers match or {timeout}s elapses.\n"
        "\n"
        "Expected convergence targets:\n"
        "{% for device, device_data in parameters.devices.items() %}"
        "- {{ device }}:\n"
        "{% for neighbor, state in device_data.neighbors.items() %}"
        "  - {{ neighbor }}: expected state={{ state }}\n"
        "{% endfor %}"
        "{% endfor %}"
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when all BGP peer states match expected state.\n"
        "- Fail if peer states do not converge within the configured timeout."
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

    async def gather_state(self, context: Context) -> BgpPeeringGateParameters:
        devices: dict[str, BgpPeeringGateDeviceParameters] = {}
        for device in context.targets:
            result = await context.broker.execute(device, self.command, use_cache=False)
            parsed = mn.parse(os=device.os, command=self.command, output=result.output)
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            af_data = next(iter(parsed["address_families"].values()))
            neighbors: dict[str, str] = {}
            for neighbor, data in af_data["neighbors"].items():
                neighbors[neighbor] = str(data.get("state_pfxrcd", ""))
            devices[device.name] = {"neighbors": neighbors}
        return {
            "timeout": DEFAULT_TIMEOUT,
            "interval": DEFAULT_INTERVAL,
            "devices": devices,
        }

    async def compare_state(
        self,
        *,
        expected: BgpPeeringGateParameters,
        current: BgpPeeringGateParameters,
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


def _is_established(state: str) -> bool:
    """A numeric state_pfxrcd value indicates an established BGP session."""
    try:
        int(state)
        return True
    except ValueError:
        return False


def _check_convergence(
    expected: BgpPeeringGateParameters,
    current: BgpPeeringGateParameters,
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
        for neighbor, expected_state in expected_device["neighbors"].items():
            current_state = current_neighbors.get(neighbor, "")
            if _is_established(expected_state):
                # Expected to be established: check current is also established
                if not _is_established(current_state):
                    device_issues.append(
                        PEER_NOT_ESTABLISHED.format(
                            device=device_name,
                            neighbor=neighbor,
                            current=current_state,
                        )
                    )
            else:
                # Expected to be in a specific non-established state
                if current_state != expected_state:
                    device_issues.append(
                        PEER_STATE_MISMATCH.format(
                            device=device_name,
                            neighbor=neighbor,
                            expected=expected_state,
                            current=current_state,
                        )
                    )
        if device_issues:
            issues[device_name] = device_issues
    return issues
