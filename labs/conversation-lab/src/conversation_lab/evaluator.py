from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .engine import Transcript
from .scenarios import Scenario


@dataclass(frozen=True)
class EvaluationReport:
    scenario_id: str
    passed: bool
    failures: list[str]
    metrics: dict[str, Any]


def evaluate_transcript(scenario: Scenario, transcript: Transcript) -> EvaluationReport:
    expected = scenario.expected
    failures: list[str] = []
    decisions = transcript.decisions
    actions = [decision.get("action") for decision in decisions]
    final_draft = transcript.final_draft or {}

    if expected.get("must_publish") is True and not transcript.published:
        failures.append("expected publish but transcript did not publish")
    if expected.get("must_publish") is False and transcript.published:
        failures.append("expected no publish but transcript published")
    if expected.get("final_action") and (not actions or actions[-1] != expected["final_action"]):
        failures.append(f"expected final action {expected['final_action']}, got {actions[-1] if actions else None}")
    for forbidden in expected.get("final_actions_forbidden", []):
        if forbidden in actions:
            failures.append(f"forbidden action appeared: {forbidden}")

    if expected.get("city") and final_draft.get("city") != expected["city"]:
        failures.append(f"expected city {expected['city']}, got {final_draft.get('city')}")
    if expected.get("activity_type_contains"):
        actual = str(final_draft.get("activity_type") or "")
        if expected["activity_type_contains"] not in actual:
            failures.append(f"activity_type missing {expected['activity_type_contains']}: {actual}")
    if expected.get("location_contains"):
        actual = str(final_draft.get("location") or "")
        if expected["location_contains"] not in actual:
            failures.append(f"location missing {expected['location_contains']}: {actual}")
    for item in expected.get("location_forbidden", []):
        actual = str(final_draft.get("location") or "")
        if item in actual:
            failures.append(f"forbidden location text remained: {item}")

    all_text = _draft_text(final_draft)
    for item in expected.get("preferences_any", []):
        if item not in all_text:
            failures.append(f"expected draft text to include {item}")
    for item in expected.get("forbidden_preferences", []):
        if item in all_text:
            failures.append(f"forbidden text leaked into draft: {item}")
    for item in expected.get("questions_any", []):
        if item not in _question_text(decisions):
            failures.append(f"expected a question mentioning {item}")

    if len(actions) > 6:
        failures.append(f"too many assistant turns: {len(actions)}")
    if actions.count("clarify") > 3:
        failures.append(f"too many clarification rounds: {actions.count('clarify')}")

    return EvaluationReport(
        scenario_id=scenario.id,
        passed=not failures,
        failures=failures,
        metrics={
            "assistant_turns": len(actions),
            "clarify_rounds": actions.count("clarify"),
            "published": transcript.published,
            "actions": actions,
        },
    )


def _draft_text(draft: dict[str, Any]) -> str:
    parts = []
    for value in draft.values():
        if isinstance(value, list):
            parts.extend(str(item) for item in value)
        else:
            parts.append(str(value))
    return " ".join(parts)


def _question_text(decisions: list[dict[str, Any]]) -> str:
    parts = []
    for decision in decisions:
        for question in decision.get("questions") or []:
            parts.append(str(question.get("title") or ""))
            parts.append(str(question.get("category") or ""))
            for option in question.get("options") or []:
                parts.append(str(option.get("label") or ""))
    return " ".join(parts)
