"""Shared utilities for local jobs."""

from __future__ import annotations

from abc import abstractmethod
from collections.abc import Iterable
from typing import Any

import muninn

from huginn import (
    Context,
    Observation,
    OperatorVolatileLearningTestCase,
)

__all__ = [
    "Observation",
    "VolatileLearningTestCase",
]

mn = muninn.Muninn()
mn.load_builtin_parsers()


class VolatileLearningTestCase(OperatorVolatileLearningTestCase):
    """Muninn-aware volatile job base class.

    Subclasses declare ``SERIES_PREFIX`` and ``command``, then implement
    :meth:`extract_observations` to yield observations from the parsed
    output.
    """

    async def gather_observations(
        self,
        context: Context,
    ) -> Iterable[Observation]:
        observations: list[Observation] = []
        for device in context.targets:
            result = await context.broker.execute(device, self.command)
            parsed = mn.parse(
                os=device.os,
                command=self.command,
                output=result.output,
            )
            context.results.add_command_execution(
                device=device.name,
                command=self.command,
                output=result,
                parsed=parsed,
            )
            observations.extend(self.extract_observations(device.name, parsed))
        return observations

    @abstractmethod
    def extract_observations(
        self,
        device_name: str,
        parsed: dict[str, Any],
    ) -> Iterable[Observation]: ...
