from __future__ import annotations

from dataclasses import dataclass, field
from copy import deepcopy
from typing import Any

from .normalizer import normalize_decision
from .prompts import load_prompt
from .kimi_backend import KimiBackend
from .rule_backend import RuleBackend
from .scenarios import Scenario
from .user_agents import ScriptedUserAgent


@dataclass
class Turn:
    role: str
    content: str
    decision: dict[str, Any] | None = None


@dataclass
class Transcript:
    scenario_id: str
    turns: list[Turn] = field(default_factory=list)
    final_draft: dict[str, Any] = field(default_factory=dict)
    published: bool = False

    @property
    def decisions(self) -> list[dict[str, Any]]:
        return [turn.decision for turn in self.turns if turn.decision is not None]


class ConversationEngine:
    def __init__(self, prompt: str, backend: RuleBackend, max_turns: int = 8):
        self.prompt = prompt
        self.backend = backend
        self.max_turns = max_turns

    @classmethod
    def from_prompt_name(cls, prompt_name: str, backend: str = "rule") -> "ConversationEngine":
        prompt = load_prompt(prompt_name)
        if backend == "rule":
            return cls(prompt=prompt, backend=RuleBackend())
        if backend == "kimi":
            return cls(prompt=prompt, backend=KimiBackend(prompt=prompt))
        raise ValueError(f"Unknown backend: {backend}")

    def run_scenario(self, scenario: Scenario) -> Transcript:
        user = ScriptedUserAgent(scenario)
        transcript = Transcript(scenario_id=scenario.id)
        state: dict[str, Any] = {
            "draft": {},
            "pending_questions": [],
            "asked_question_ids": set(),
            "user_profile": scenario.user_profile,
        }
        last_decision: dict[str, Any] | None = None

        for _ in range(self.max_turns):
            message = user.next_message(last_decision)
            if not message:
                break
            transcript.turns.append(Turn(role="user", content=message))

            if last_decision and last_decision.get("action") == "draft" and "确认" in message:
                transcript.published = True
                transcript.final_draft = dict(state.get("draft") or {})
                transcript.turns.append(Turn(
                    role="assistant",
                    content="已发布",
                    decision={"action": "published", "reply": "已发布", "draft": transcript.final_draft, "questions": []},
                ))
                break

            messages = [
                {"role": turn.role, "content": turn.content}
                for turn in transcript.turns
                if turn.role in {"user", "assistant"}
            ]
            decision = normalize_decision(self.backend.decide(messages, state))
            self._apply_decision_to_state(state, decision)
            last_decision = decision
            transcript.turns.append(Turn(role="assistant", content=decision["reply"], decision=deepcopy(decision)))

            if decision["action"] == "cancel":
                break

        if not transcript.final_draft:
            transcript.final_draft = dict(state.get("draft") or {})
        return transcript

    def _apply_decision_to_state(self, state: dict[str, Any], decision: dict[str, Any]) -> None:
        action = decision.get("action")
        if action in {"clarify", "draft"}:
            state["draft"] = deepcopy(decision.get("draft") or {})
        if action == "clarify":
            questions = list(decision.get("questions") or [])
            state["pending_questions"] = questions
            state.setdefault("asked_question_ids", set()).update(
                str(question.get("id") or "") for question in questions
            )
        else:
            state["pending_questions"] = []
        if action == "cancel":
            state["draft"] = {}
            state["pending_questions"] = []
