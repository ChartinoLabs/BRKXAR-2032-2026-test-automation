"""Volatile version test: device uptime observation chain."""

from collections.abc import Iterable
from typing import Any

from huginn import Observation, parse_duration_seconds

from jobs.utils import VolatileLearningTestCase


class VerifyVersionUptimeIncreased(VolatileLearningTestCase):
    """Observation chain for device uptime from `show version`."""

    DESCRIPTION = (
        "Validate that each device's uptime satisfies the expected comparison "
        "operator relative to the most recent prior observation within this run."
    )
    SETUP = (
        "- Devices are reachable over SSH.\n"
        "- The `show version` command is supported on applicable targets."
    )
    PROCEDURE = (
        "- Execute `show version` on each applicable device.\n"
        "- Parse and extract `uptime`.\n"
        "- Write observations to the run's observation log and compare against "
        "the most recent prior observation using operator "
        "'{{ parameters.operator }}'."
    )
    PASS_FAIL_CRITERIA = (
        "- Pass when the device's uptime satisfies the comparison operator "
        "relative to the prior observation.\n"
        "- Skip comparison when this is the first observation in the run.\n"
        "- Fail if the uptime violates the comparison operator "
        "(indicating an unexpected reload)."
    )

    SERIES_PREFIX = "version-uptime"
    command = "show version"

    def extract_observations(
        self,
        device_name: str,
        parsed: dict[str, Any],
    ) -> Iterable[Observation]:
        raw = str(parsed.get("uptime", ""))
        if not raw:
            return
        yield Observation(
            device=device_name,
            series_key="uptime",
            value=parse_duration_seconds(raw),
            raw=raw,
        )
