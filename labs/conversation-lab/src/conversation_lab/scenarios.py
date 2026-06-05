from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCENARIO_DIR = ROOT / "scenarios"


@dataclass(frozen=True)
class Scenario:
    id: str
    name: str
    initial_message: str
    user_profile: dict[str, Any]
    answers: dict[str, str]
    expected: dict[str, Any]


def load_scenarios(name: str = "core") -> list[Scenario]:
    path = SCENARIO_DIR / f"{name}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    return [
        Scenario(
            id=item["id"],
            name=item["name"],
            initial_message=item["initial_message"],
            user_profile=item.get("user_profile", {}),
            answers=item.get("answers", {}),
            expected=item.get("expected", {}),
        )
        for item in data
    ]
