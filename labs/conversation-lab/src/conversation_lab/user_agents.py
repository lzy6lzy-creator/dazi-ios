from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .scenarios import Scenario


@dataclass
class ScriptedUserAgent:
    """A deterministic user simulator driven by scenario answers."""

    scenario: Scenario
    turn_index: int = 0
    answered_question_ids: set[str] = field(default_factory=set)
    draft_response_used: bool = False

    def next_message(self, last_decision: dict[str, Any] | None) -> str:
        if last_decision is None:
            return self.scenario.initial_message

        action = last_decision.get("action")
        if action == "draft":
            if self.scenario.answers.get("draft_response") and not self.draft_response_used:
                self.draft_response_used = True
                return self.scenario.answers["draft_response"]
            cancellation = self.scenario.answers.get("default")
            if cancellation and any(token in cancellation for token in ("算了", "不发布", "取消", "不要了")):
                return cancellation
            return "确认发布"
        if action == "cancel":
            return ""
        if action == "chat":
            return self.scenario.answers.get("default", "")
        if action == "clarify":
            return self._answer_questions(last_decision.get("questions") or [])
        return self._answer_for_key("default", fallback="都可以")

    def _answer_questions(self, questions: list[dict[str, Any]]) -> str:
        replies = []
        for question in questions:
            question_id = str(question.get("id") or "")
            if question_id in self.answered_question_ids:
                continue
            self.answered_question_ids.add(question_id)
            replies.append(self._answer_for_question(question))
        if not replies:
            return self._answer_for_key("default", fallback="都可以，帮我发布前整理一下")
        return "；".join(replies)

    def _answer_for_question(self, question: dict[str, Any]) -> str:
        question_id = str(question.get("id") or "")
        if question_id in self.scenario.answers:
            return self._answer_for_key(question_id, fallback="都可以")
        target = " ".join([
            question_id,
            str(question.get("title") or ""),
            str(question.get("category") or ""),
        ]).lower()
        mapping = [
            (("budget", "预算", "人均", "费用"), "budget"),
            (("area", "片区"), "area"),
            (("location", "area", "地点", "区域", "哪里"), "location"),
            (("spice", "辣", "口味"), "spice"),
            (("skill", "level", "水平"), "skill"),
            (("time", "时间", "几点", "周几"), "time"),
            (("age", "年龄", "同龄"), "age"),
        ]
        for keywords, key in mapping:
            if any(keyword in target for keyword in keywords):
                return self._answer_for_key(key, fallback="都可以")
        return self._answer_for_key("default", fallback="都可以")

    def _answer_for_key(self, key: str, fallback: str) -> str:
        return self.scenario.answers.get(key) or fallback
