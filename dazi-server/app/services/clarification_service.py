from __future__ import annotations

from copy import deepcopy
from datetime import date
import re
from typing import Any


MAX_OPTIONS = 6
_CONVERSATION_ACTIONS = {"chat", "clarify", "draft", "cancel"}
_DRAFT_STRING_FIELDS = ("title", "activity_type", "location", "start_time", "end_time")
_DRAFT_LIST_FIELDS = ("preferences", "constraints")
_AGE_FILTER_MODE_VALUES = {"preference", "hard_filter"}
_LOCATION_QUESTION_IDS = {"city", "location", "area", "place", "district", "region"}
_EVENT_QUESTION_IDS = {"event", "activity", "activity_type"}
_EXACT_TITLE_IDS = {
    "时间": "time",
    "地点": "location",
    "年龄": "age",
    "性别": "gender",
    "预算": "budget",
    "具体偏好类型": "preferences",
    "其他title": "question",
}
_FIXED_OPTION_LABELS = {
    "gender": ("男", "女", "优先男", "优先女", "不限"),
    "age": ("+-3", "+-5", "+-10", "不限"),
}


class ConversationQuestionNormalizer:
    """Convert lightweight LLM question_json into client ClarificationQuestion shape."""

    def __init__(self):
        self._stream_counts: dict[str, int] = {}

    def normalize_next(self, raw_question: Any) -> dict | None:
        return _normalize_question(raw_question, self._stream_counts)

    def normalize_questions(self, raw_questions: list[Any]) -> list[dict]:
        counts: dict[str, int] = {}
        questions = []
        for raw_question in raw_questions:
            question = _normalize_question(raw_question, counts)
            if question:
                questions.append(question)
        return questions

    def normalize_payload(self, payload: Any) -> dict:
        return normalize_conversation_payload(payload, question_normalizer=self)


def normalize_clarification_payload(payload: Any) -> dict:
    """Normalize an LLM clarification JSON payload into a client-safe shape."""
    if not isinstance(payload, dict):
        return {"reply": "", "questions": [], "draft": {}}

    reply = str(payload.get("reply") or "").strip()
    raw_questions = payload.get("questions") if payload.get("needs_clarification", True) else []
    if not isinstance(raw_questions, list):
        raw_questions = []

    questions = ConversationQuestionNormalizer().normalize_questions(raw_questions)

    draft = _sanitize_draft(payload.get("draft"))

    return {
        "reply": reply,
        "questions": questions,
        "draft": draft,
    }


def normalize_conversation_payload(
    payload: Any,
    *,
    question_normalizer: ConversationQuestionNormalizer | None = None,
) -> dict:
    """Normalize the main conversation orchestrator JSON into a safe shape."""
    if not isinstance(payload, dict):
        return {"action": "chat", "reply": "", "questions": [], "draft": {}}

    action = str(payload.get("action") or "chat").strip().lower()
    if action not in _CONVERSATION_ACTIONS:
        action = "chat"

    reply = str(payload.get("reply") or "").strip()
    draft = _sanitize_draft(payload.get("draft"))

    raw_questions = payload.get("questions") if action == "clarify" else []
    if not isinstance(raw_questions, list):
        raw_questions = []

    normalizer = question_normalizer or ConversationQuestionNormalizer()
    questions = normalizer.normalize_questions(raw_questions)

    return {
        "action": action,
        "reply": reply,
        "questions": questions,
        "draft": draft,
    }


def merge_clarification_answers(
    *,
    draft: dict,
    questions: list[dict],
    answers: list[dict],
    user_birth_date: date | None,
    today: date | None = None,
    free_text: str | None = None,
) -> dict:
    """Merge structured card answers into an event draft."""
    merged = deepcopy(draft) if isinstance(draft, dict) else {}
    merged.setdefault("preferences", [])
    merged.setdefault("constraints", [])
    merged.setdefault("clarification_answers", [])

    if not isinstance(answers, list):
        answers = []

    question_by_id = {
        str(question.get("id")): question
        for question in questions
        if isinstance(question, dict) and question.get("id")
    }

    for answer in answers:
        if not isinstance(answer, dict):
            continue
        question_id = str(answer.get("question_id") or "")
        question = question_by_id.get(question_id)
        if not question:
            continue
        merged["clarification_answers"].append(answer)

        if question.get("type") == "age_range":
            _merge_age_answer(
                merged=merged,
                question=question,
                answer=answer,
                user_birth_date=user_birth_date,
                today=today or date.today(),
            )
        else:
            _merge_generic_answer(merged, question, answer)

    free_text = (free_text or "").strip()
    if free_text:
        merged["preferences"].append(free_text)

    return merged


def _normalize_question(raw_question: Any, counts: dict[str, int]) -> dict | None:
    if not isinstance(raw_question, dict):
        return None

    title = str(raw_question.get("title") or "").strip()
    raw_options = raw_question.get("options")
    if not title or not isinstance(raw_options, list) or not raw_options:
        return None

    base_id = _base_question_id(raw_question, title)
    question_id = _unique_question_id(base_id, counts)
    question_type = _question_type(raw_question, base_id)

    option_source = _fixed_option_source(base_id, raw_options)
    options = []
    aliases_by_id: dict[str, set[str]] = {}
    for opt_index, raw_option in enumerate(option_source[:MAX_OPTIONS]):
        option, aliases = _normalize_option(raw_option, question_id, opt_index, question_type)
        if option:
            aliases.update(_fixed_option_aliases(base_id, option["label"]))
            options.append(option)
            aliases_by_id[option["id"]] = aliases
    if not options:
        return None

    category = str(raw_question.get("category") or _category_for_question(base_id, title)).strip()
    match_filter = raw_question.get("match_filter")
    if match_filter not in {"preference", "hard_filter", None}:
        match_filter = None

    return {
        "id": question_id,
        "type": question_type,
        "title": title,
        "helper_text": str(raw_question.get("helper_text") or "").strip(),
        "category": category,
        "required": bool(raw_question.get("required", False)),
        "allow_custom": bool(raw_question.get("allow_custom", True)),
        "match_filter": match_filter,
        "options": options,
        "default_option_ids": _normalize_default_option_ids(
            raw_question.get("default_option_ids"),
            options,
            aliases_by_id,
            base_id,
        ),
    }


def _sanitize_draft(raw_draft: Any) -> dict:
    if not isinstance(raw_draft, dict):
        return {}

    draft: dict[str, Any] = {}
    for field in _DRAFT_STRING_FIELDS:
        value = _clean_string(raw_draft.get(field))
        if value:
            draft[field] = value

    legacy_city = _clean_string(raw_draft.get("city"))
    if "location" not in draft and legacy_city:
        draft["location"] = legacy_city

    for field in _DRAFT_LIST_FIELDS:
        if field in raw_draft:
            draft[field] = _clean_string_list(raw_draft.get(field))

    age_min = _safe_int(raw_draft.get("age_filter_min"))
    age_max = _safe_int(raw_draft.get("age_filter_max"))
    if age_min is not None and age_max is not None:
        if age_min > age_max:
            age_min, age_max = age_max, age_min
        draft["age_filter_min"] = age_min
        draft["age_filter_max"] = age_max
        mode = _clean_string(raw_draft.get("age_filter_mode")) or "preference"
        draft["age_filter_mode"] = mode if mode in _AGE_FILTER_MODE_VALUES else "preference"

    _remove_place_labels_from_lists(
        draft,
        _place_labels_for_cleanup(draft.get("location"), legacy_city),
    )

    return draft


def _clean_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    return cleaned or None


def _clean_string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    cleaned: list[str] = []
    for item in value:
        text = _clean_string(item)
        if text and text not in cleaned:
            cleaned.append(text)
    return cleaned


def _base_question_id(raw_question: dict, title: str) -> str:
    if title in _EXACT_TITLE_IDS:
        return _EXACT_TITLE_IDS[title]

    text = f"{raw_question.get('category') or ''} {title}".strip()
    if any(keyword in text for keyword in ("时间", "几点", "什么时候", "日期", "上午", "下午", "晚上")):
        return "time"
    if any(keyword in text for keyword in ("地点", "位置", "城市", "区域", "哪片区", "哪里", "在哪")):
        return "location"
    if any(keyword in text for keyword in ("年龄", "同龄", "岁")):
        return "age"
    if any(keyword in text for keyword in ("性别", "男", "女", "同性", "异性")):
        return "gender"
    if any(keyword in text for keyword in ("预算", "价格", "费用", "人均", "AA", "aa")):
        return "budget"
    if any(keyword in text for keyword in ("偏好", "要求", "口味", "水平", "技能", "特殊")):
        return "preferences"
    if any(keyword in text for keyword in ("活动", "想做什么", "项目")):
        return "event"
    return "question"


def _unique_question_id(base_id: str, counts: dict[str, int]) -> str:
    counts[base_id] = counts.get(base_id, 0) + 1
    if counts[base_id] == 1:
        return base_id
    return f"{base_id}_{counts[base_id]}"


def _question_type(raw_question: dict, base_id: str) -> str:
    if base_id == "age":
        return "age_range"
    choice = str(raw_question.get("choice") or "").strip().lower()
    if choice == "multi":
        return "multi_choice"
    if choice == "single":
        return "single_choice"
    question_type = str(raw_question.get("type") or "single_choice").strip()
    if question_type in {"single_choice", "multi_choice", "age_range"}:
        return question_type
    return "single_choice"


def _category_for_question(base_id: str, title: str) -> str:
    return {
        "time": "时间",
        "location": "地点",
        "age": "年龄",
        "gender": "偏好",
        "budget": "预算",
        "preferences": "偏好",
        "event": "活动",
    }.get(base_id, title or "偏好")


def _fixed_option_source(base_id: str, raw_options: list) -> list:
    labels = _FIXED_OPTION_LABELS.get(base_id)
    if labels:
        return list(labels)
    return raw_options


def _normalize_option(
    raw_option: Any,
    question_id: str,
    index: int,
    question_type: str,
) -> tuple[dict | None, set[str]]:
    aliases: set[str] = set()
    if isinstance(raw_option, str):
        label = raw_option.strip()
        value = _option_value_for_label(label, question_type)
    elif isinstance(raw_option, dict):
        label = str(raw_option.get("label") or raw_option.get("value") or "").strip()
        value = raw_option.get("value") if "value" in raw_option else _option_value_for_label(label, question_type)
        raw_id = str(raw_option.get("id") or "").strip()
        if raw_id:
            aliases.add(raw_id)
    else:
        return None, aliases
    if not label:
        return None, aliases
    option_id = f"{question_id}_{index + 1}"
    aliases.update({option_id, label})
    return {
        "id": option_id,
        "label": label,
        "value": value,
    }, aliases


def _fixed_option_aliases(base_id: str, label: str) -> set[str]:
    if base_id == "gender":
        return _gender_option_aliases(label)
    if base_id == "age":
        return _age_option_aliases(label)
    return set()


def _gender_option_aliases(label: str) -> set[str]:
    aliases = {label}
    if label == "男":
        aliases.update({"男生", "男性", "只要男生", "只找男生", "仅限男生", "必须男生", "只限男生", "男搭子"})
    elif label == "女":
        aliases.update({"女生", "女性", "只要女生", "只找女生", "仅限女生", "必须女生", "只限女生", "女搭子"})
    elif label == "优先男":
        aliases.update({"男生优先", "优先男生", "偏男", "偏向男生", "优先男性"})
    elif label == "优先女":
        aliases.update({"女生优先", "优先女生", "偏女", "偏向女生", "优先女性"})
    elif label == "不限":
        aliases.update({"不限男女", "男女不限", "不限性别", "随便", "都可以", "无所谓"})
    return aliases


def _age_option_aliases(label: str) -> set[str]:
    aliases = {label}
    if label == "+-3":
        aliases.update({"±3", "+/-3", "-3 到 +3", "-3到+3", "-3 到 +3 岁", "上下3岁"})
    elif label == "+-5":
        aliases.update({"±5", "+/-5", "-5 到 +5", "-5到+5", "-5 到 +5 岁", "上下5岁", "同龄", "同龄就行", "同龄优先"})
    elif label == "+-10":
        aliases.update({"±10", "+/-10", "-10 到 +10", "-10到+10", "-10 到 +10 岁", "上下10岁"})
    elif label == "不限":
        aliases.update({"不限年龄", "年龄不限", "不限制年龄", "都可以", "随便"})
    return aliases


def _option_value_for_label(label: str, question_type: str) -> Any:
    if question_type != "age_range":
        return label
    if "不限" in label:
        return None
    radius = _age_radius_from_label(label)
    if radius is not None:
        return {"range": radius}
    return label


def _age_radius_from_label(label: str) -> int | None:
    plus_minus = re.search(r"(?:±|\+/-|\+-)\s*(\d+)", label)
    if plus_minus:
        return _safe_int(plus_minus.group(1))

    range_match = re.search(r"[-−]?\s*(\d+)\s*(?:到|~|至|-)\s*\+?\s*(\d+)", label)
    if range_match:
        left = _safe_int(range_match.group(1))
        right = _safe_int(range_match.group(2))
        if left is not None and right is not None:
            return max(left, right)
    return None


def _normalize_default_option_ids(
    value: Any,
    options: list[dict],
    aliases_by_id: dict[str, set[str]],
    base_id: str,
) -> list[str]:
    if not isinstance(value, list):
        value = []
    result: list[str] = []
    for item in value:
        text = str(item).strip()
        if not text:
            continue
        for option in options:
            option_id = str(option.get("id") or "")
            if not option_id or option_id in result:
                continue
            if text in aliases_by_id.get(option_id, set()):
                result.append(option_id)
                break
    if result:
        return result
    if base_id == "age":
        for option in options:
            if option.get("label") == "+-5" and option.get("id"):
                return [str(option["id"])]
    return result


def _merge_generic_answer(merged: dict, question: dict, answer: dict) -> None:
    option_ids = answer.get("option_ids")
    if not isinstance(option_ids, list):
        option_ids = []

    options = {
        str(option.get("id")): option
        for option in question.get("options", [])
        if isinstance(option, dict)
    }
    labels = []
    for option_id in option_ids:
        option = options.get(str(option_id))
        if not option:
            continue
        value = option.get("value")
        if isinstance(value, dict):
            _apply_draft_value(merged, value)
            continue
        if isinstance(value, str) and value.strip():
            labels.append(value.strip())
            continue
        label = str(option.get("label") or "").strip()
        if label:
            labels.append(label)

    custom_value = answer.get("custom_value")
    if isinstance(custom_value, dict):
        _apply_draft_value(merged, custom_value)
    elif isinstance(custom_value, str) and custom_value.strip():
        labels.append(custom_value.strip())

    if _is_event_question(question):
        activity_type = "、".join(dict.fromkeys(labels)).strip()
        if activity_type:
            merged["activity_type"] = activity_type
        return

    if _is_location_question(question):
        location = "、".join(dict.fromkeys(labels)).strip()
        if location:
            merged["location"] = location
            _remove_place_labels_from_lists(merged, labels)
        return

    target = "constraints" if question.get("match_filter") == "hard_filter" else "preferences"
    for label in labels:
        if label not in merged[target]:
            merged[target].append(label)


def _apply_draft_value(merged: dict, value: dict) -> None:
    for field in _DRAFT_STRING_FIELDS:
        text = _clean_string(value.get(field))
        if text:
            merged[field] = text
    for field in _DRAFT_LIST_FIELDS:
        additions = _clean_string_list(value.get(field))
        if additions:
            merged.setdefault(field, [])
            for item in additions:
                if item not in merged[field]:
                    merged[field].append(item)
    _remove_place_labels_from_lists(
        merged,
        _place_labels_for_cleanup(value.get("location")),
    )


def _is_event_question(question: dict) -> bool:
    question_id = str(question.get("id") or "").strip().lower()
    if question_id in _EVENT_QUESTION_IDS:
        return True
    title = str(question.get("title") or "").strip()
    category = str(question.get("category") or "").strip()
    text = f"{category} {title}"
    return any(keyword in text for keyword in ("事件", "活动", "想做什么", "项目"))


def _is_location_question(question: dict) -> bool:
    question_id = str(question.get("id") or "").strip().lower()
    if question_id in _LOCATION_QUESTION_IDS:
        return True

    category = str(question.get("category") or "").strip()
    title = str(question.get("title") or "").strip()
    text = f"{category} {title}"
    return any(keyword in text for keyword in ("地点", "位置", "城市", "区域", "哪片区", "哪里", "在哪"))


def _place_labels_for_cleanup(*values: Any) -> list[str]:
    labels: list[str] = []
    for value in values:
        text = _clean_string(value)
        if text and text not in labels:
            labels.append(text)
    return labels


def _remove_place_labels_from_lists(draft: dict, labels: list[str]) -> None:
    if not labels:
        return
    label_set = {label.strip() for label in labels if label.strip()}
    if not label_set:
        return
    for field in _DRAFT_LIST_FIELDS:
        values = draft.get(field)
        if isinstance(values, list):
            draft[field] = [item for item in values if item not in label_set]


def _merge_age_answer(
    *,
    merged: dict,
    question: dict,
    answer: dict,
    user_birth_date: date | None,
    today: date,
) -> None:
    age_min: int | None = None
    age_max: int | None = None
    mode = question.get("match_filter") or "preference"
    if mode not in {"preference", "hard_filter"}:
        mode = "preference"

    custom = answer.get("custom_value")
    if isinstance(custom, dict):
        age_min = _safe_int(custom.get("min_age"))
        age_max = _safe_int(custom.get("max_age"))

    if age_min is None or age_max is None:
        option_ids = answer.get("option_ids")
        if not isinstance(option_ids, list):
            option_ids = []
        options = {
            str(option.get("id")): option
            for option in question.get("options", [])
            if isinstance(option, dict)
        }
        for option_id in option_ids:
            option = options.get(str(option_id))
            if not option:
                continue
            value = option.get("value")
            label = str(option.get("label") or "")
            if value is None or "不限制" in label:
                return
            if isinstance(value, dict) and _safe_int(value.get("range")) is not None and user_birth_date:
                user_age = age_on_date(user_birth_date, today)
                radius = _safe_int(value.get("range")) or 0
                age_min = max(18, user_age - radius)
                age_max = user_age + radius
                break

    if age_min is None or age_max is None:
        return
    if age_min > age_max:
        age_min, age_max = age_max, age_min

    merged["age_filter_min"] = age_min
    merged["age_filter_max"] = age_max
    merged["age_filter_mode"] = mode

    label = f"年龄范围 {age_min}-{age_max} 岁"
    if mode == "hard_filter":
        if label not in merged["constraints"]:
            merged["constraints"].append(label)
    else:
        pref = f"年龄偏好 {age_min}-{age_max} 岁"
        if pref not in merged["preferences"]:
            merged["preferences"].append(pref)


def age_on_date(birth_date: date, today: date) -> int:
    age = today.year - birth_date.year
    if (today.month, today.day) < (birth_date.month, birth_date.day):
        age -= 1
    return age


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
