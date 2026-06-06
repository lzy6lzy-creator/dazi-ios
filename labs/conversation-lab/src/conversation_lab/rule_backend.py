from __future__ import annotations

from typing import Any


class RuleBackend:
    """Offline approximation of the orchestrator contract for repeatable lab tests."""

    def decide(self, messages: list[dict[str, str]], state: dict[str, Any]) -> dict[str, Any]:
        latest = messages[-1]["content"] if messages else ""
        text = latest.strip()
        lowered = text.lower()

        if _is_cancel(text):
            return {"action": "cancel", "reply": "好，那我先不发布。", "draft": {}, "questions": []}

        draft = dict(state.get("draft") or {})
        pending_questions = state.get("pending_questions") or []
        if draft and _is_revision(text) and not pending_questions:
            _merge_answer_text(draft, text, [])
            return {
                "action": "draft",
                "reply": self._draft_reply(draft),
                "draft": draft,
                "questions": [],
            }

        if pending_questions:
            _merge_answer_text(draft, text, pending_questions)
            questions = self._questions_for(draft, state)
            if questions:
                return {
                    "action": "clarify",
                    "reply": "我更新了一下条件，再确认几个会影响匹配的小点。",
                    "draft": draft,
                    "questions": questions,
                }
            return {
                "action": "draft",
                "reply": self._draft_reply(draft),
                "draft": draft,
                "questions": [],
            }

        if _is_casual_chat(text):
            return {
                "action": "chat",
                "reply": "可以先别急着发布。你想出门的话，我可以帮你把想做的事整理成活动。",
                "draft": {},
                "questions": [],
            }

        draft = _extract_initial_draft(text, state.get("user_profile") or {})
        if not draft:
            return {"action": "chat", "reply": "你想找搭子做什么？", "draft": {}, "questions": []}

        questions = self._questions_for(draft, state)
        if questions:
            return {
                "action": "clarify",
                "reply": "我先确认几个会影响匹配的小点。",
                "draft": draft,
                "questions": questions,
            }
        return {"action": "draft", "reply": self._draft_reply(draft), "draft": draft, "questions": []}

    def _questions_for(self, draft: dict[str, Any], state: dict[str, Any]) -> list[dict[str, Any]]:
        questions = []
        asked = set(state.get("asked_question_ids") or [])
        activity = str(draft.get("activity_type") or "")
        prefs = " ".join(draft.get("preferences") or [])
        constraints = " ".join(draft.get("constraints") or [])
        location = " ".join([str(draft.get("city") or ""), str(draft.get("location") or "")])

        if not (draft.get("city") or draft.get("location")):
                _append_if_new(questions, asked, _question("location", "更想在哪片区域？", ["离我近", "市中心", "都可以"], "地点"))

        if activity in {"火锅", "吃饭", "约饭"}:
            if "预算" not in prefs and not any("50" in p or "80" in p or "100" in p for p in draft.get("preferences", [])):
                _append_if_new(questions, asked, _question("budget", "人均预算大概多少？", ["50-80", "80-120", "都可以"], "预算"))
            if "辣" not in constraints and "不吃辣" not in constraints:
                _append_if_new(questions, asked, _question("spice", "口味有什么限制？", ["能吃辣", "不吃辣", "都可以"], "偏好"))

        if activity in {"网球", "羽毛球", "篮球", "打球"}:
            if not any(token in prefs for token in ("周六", "周日", "下午", "晚上")):
                _append_if_new(questions, asked, _question("time", "大概什么时候方便？", ["周六下午", "周日", "都可以"], "时间"))
            if "新手" not in prefs and "水平" not in prefs:
                _append_if_new(questions, asked, _question("skill", "希望对方什么水平？", ["差不多水平", "新手也行", "随便玩玩"], "偏好"))
            if "AA" not in prefs and "费用" not in prefs:
                _append_if_new(questions, asked, _question("budget", "场地费用怎么安排？", ["场地费 AA", "我请客", "都可以"], "预算"))

        if activity in {"酒吧", "小酌"}:
            if "年龄" not in prefs and "同龄" not in prefs:
                _append_if_new(questions, asked, _question("age", "年龄需要偏好范围吗？", ["同龄优先", "不限制"], "年龄"))

        if "上海" in location and activity == "火锅" and "徐汇" not in location and "静安" not in location:
            _append_if_new(questions, asked, _question("area", "上海更偏向哪片区域？", ["徐汇/静安", "浦东", "都可以"], "地点"))

        return questions[:3]

    def _draft_reply(self, draft: dict[str, Any]) -> str:
        title = draft.get("title") or draft.get("activity_type") or "这次活动"
        place = " / ".join([item for item in [draft.get("city"), draft.get("location")] if item])
        parts = [f"我帮你整理好了：{title}"]
        if place:
            parts.append(f"地点偏向 {place}")
        if draft.get("preferences"):
            parts.append(f"偏好：{'、'.join(draft['preferences'][:4])}")
        if draft.get("constraints"):
            parts.append(f"限制：{'、'.join(draft['constraints'][:4])}")
        return "；".join(parts) + "。确认的话就点确认发布。"


def _extract_initial_draft(text: str, user_profile: dict[str, Any]) -> dict[str, Any]:
    activity = None
    if "火锅" in text:
        activity = "火锅"
    elif "网球" in text:
        activity = "网球"
    elif "咖啡" in text:
        activity = "咖啡"
    elif "酒吧" in text or "小酌" in text:
        activity = "酒吧"
    elif "吃饭" in text or "约饭" in text:
        activity = "吃饭"
    if not activity:
        return {}

    city = "上海" if "上海" in text else user_profile.get("city")
    if city in {None, "", "未设置"}:
        city = None

    draft: dict[str, Any] = {
        "title": _title_for(activity, text),
        "activity_type": activity,
        "preferences": [],
        "constraints": [],
    }
    if city:
        draft["city"] = city
    for place in ("徐汇", "静安", "浦东", "人民广场"):
        if place in text:
            draft["location"] = place
    for token in ("今晚", "明晚", "周末", "周五晚上", "周六下午"):
        if token in text:
            draft["preferences"].append(token)
    _merge_plain_constraints(draft, text)
    return draft


def _merge_answer_text(draft: dict[str, Any], text: str, questions: list[dict[str, Any]]) -> None:
    if "上海" in text:
        draft["city"] = "上海"
    for place in ("徐汇", "静安", "浦东", "人民广场"):
        if "改成" in text and place in text:
            draft["location"] = place
        elif place in text and place not in str(draft.get("location") or ""):
            existing = draft.get("location")
            draft["location"] = f"{existing}/{place}" if existing else place
    _merge_plain_preferences(draft, text)
    _merge_plain_constraints(draft, text)
    for question in questions:
        qid = question.get("id")
        if qid == "area" and ("徐汇" in text or "静安" in text):
            draft["location"] = "徐汇/静安"


def _merge_plain_preferences(draft: dict[str, Any], text: str) -> None:
    preferences = draft.setdefault("preferences", [])
    candidates = []
    for token in ("50-80", "50-80，正常吃", "100以内", "场地费 AA", "新手也行", "周六下午", "周五晚上", "同龄优先"):
        if token in text:
            candidates.append(token)
    if "正常吃" in text and "正常吃" not in candidates:
        candidates.append("正常吃")
    for item in candidates:
        if item not in preferences:
            preferences.append(item)


def _merge_plain_constraints(draft: dict[str, Any], text: str) -> None:
    constraints = draft.setdefault("constraints", [])
    if "不吃辣" in text and "不吃辣" not in constraints:
        constraints.append("不吃辣")


def _question(qid: str, title: str, labels: list[str], category: str) -> dict[str, Any]:
    return {
        "id": qid,
        "type": "single_choice",
        "title": title,
        "helper_text": "这个会影响匹配体验。",
        "category": category,
        "required": False,
        "allow_custom": True,
        "match_filter": "preference",
        "options": [
            {"id": f"option_{index + 1}", "label": label, "value": label}
            for index, label in enumerate(labels)
        ],
    }


def _append_if_new(questions: list[dict[str, Any]], asked: set[str], question: dict[str, Any]) -> None:
    if question["id"] not in asked:
        questions.append(question)


def _title_for(activity: str, text: str) -> str:
    if activity == "火锅":
        return "今晚火锅约饭" if "今晚" in text else "火锅约饭"
    if activity == "网球":
        return "周末网球搭子" if "周末" in text else "网球搭子"
    if activity == "酒吧":
        return "酒吧小酌"
    return activity


def _is_cancel(text: str) -> bool:
    return any(token in text for token in ("算了", "不发布", "取消", "不要了"))


def _is_revision(text: str) -> bool:
    return any(token in text for token in ("改成", "换成", "重新整理", "重新问"))


def _is_casual_chat(text: str) -> bool:
    return "累" in text and not any(token in text for token in ("吃", "打", "喝", "约", "找"))
