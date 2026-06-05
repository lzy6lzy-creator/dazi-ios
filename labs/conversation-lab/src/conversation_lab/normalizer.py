from __future__ import annotations

from typing import Any


VALID_ACTIONS = {"chat", "clarify", "draft", "cancel"}
STRING_DRAFT_FIELDS = ("title", "activity_type", "city", "location", "start_time", "end_time")
LIST_DRAFT_FIELDS = ("preferences", "constraints")
MAX_QUESTIONS = 3
MAX_OPTIONS = 6


def normalize_decision(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {"action": "chat", "reply": "", "draft": {}, "questions": []}

    action = str(payload.get("action") or "chat").strip().lower()
    if action not in VALID_ACTIONS:
        action = "chat"

    reply = str(payload.get("reply") or "").strip()
    draft = _sanitize_draft(payload.get("draft"))
    raw_questions = payload.get("questions") if action == "clarify" else []
    if not isinstance(raw_questions, list):
        raw_questions = []

    questions = []
    for index, raw_question in enumerate(raw_questions[:MAX_QUESTIONS]):
        question = _normalize_question(raw_question, index)
        if question:
            questions.append(question)

    return {
        "action": action,
        "reply": reply,
        "draft": draft,
        "questions": questions,
    }


def _sanitize_draft(raw_draft: Any) -> dict[str, Any]:
    if not isinstance(raw_draft, dict):
        return {}

    draft: dict[str, Any] = {}
    for field in STRING_DRAFT_FIELDS:
        value = raw_draft.get(field)
        if isinstance(value, str) and value.strip() and value.strip().lower() != "null":
            draft[field] = value.strip()

    for field in LIST_DRAFT_FIELDS:
        values = raw_draft.get(field)
        if not isinstance(values, list):
            continue
        cleaned = []
        for item in values:
            if isinstance(item, str) and item.strip() and item.strip() not in cleaned:
                cleaned.append(item.strip())
        draft[field] = cleaned

    return draft


def _normalize_question(raw_question: Any, index: int) -> dict[str, Any] | None:
    if not isinstance(raw_question, dict):
        return None
    title = str(raw_question.get("title") or "").strip()
    raw_options = raw_question.get("options")
    if not title or not isinstance(raw_options, list) or not raw_options:
        return None

    options = []
    for option_index, raw_option in enumerate(raw_options[:MAX_OPTIONS]):
        option = _normalize_option(raw_option, option_index)
        if option:
            options.append(option)
    if not options:
        return None

    match_filter = raw_question.get("match_filter")
    if match_filter not in {"preference", "hard_filter", None}:
        match_filter = None

    return {
        "id": str(raw_question.get("id") or f"question_{index + 1}").strip(),
        "type": str(raw_question.get("type") or "single_choice").strip(),
        "title": title,
        "helper_text": str(raw_question.get("helper_text") or "").strip(),
        "category": str(raw_question.get("category") or "偏好").strip(),
        "required": bool(raw_question.get("required", False)),
        "allow_custom": bool(raw_question.get("allow_custom", True)),
        "match_filter": match_filter,
        "options": options,
    }


def _normalize_option(raw_option: Any, index: int) -> dict[str, Any] | None:
    if not isinstance(raw_option, dict):
        return None
    label = str(raw_option.get("label") or "").strip()
    if not label:
        return None
    return {
        "id": str(raw_option.get("id") or f"option_{index + 1}").strip(),
        "label": label,
        "value": raw_option.get("value", label),
    }
