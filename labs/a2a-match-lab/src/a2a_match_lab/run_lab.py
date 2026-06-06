from __future__ import annotations

import argparse
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from .kimi import KimiClient


ROOT = Path(__file__).resolve().parents[2]
PROMPT_DIR = ROOT / "prompts"
SCENARIO_DIR = ROOT / "scenarios"
REPORT_DIR = ROOT / "reports"


@dataclass
class ScenarioReport:
    scenario_id: str
    title: str
    passed: bool
    score: float
    should_match: bool
    failures: list[str]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run A2A match lab against real Kimi.")
    parser.add_argument("--prompt", default="a2a_match_v3")
    parser.add_argument("--scenario-set", default="core")
    parser.add_argument("--only", default="", help="Run one scenario id.")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()

    prompt = (PROMPT_DIR / f"{args.prompt}.md").read_text(encoding="utf-8")
    scenarios = json.loads((SCENARIO_DIR / f"{args.scenario_set}.json").read_text(encoding="utf-8"))
    if args.only:
        scenarios = [scenario for scenario in scenarios if scenario["id"] == args.only]
    if args.limit:
        scenarios = scenarios[: args.limit]
    if not scenarios:
        raise SystemExit("No scenarios selected.")

    client = KimiClient()
    reports: list[ScenarioReport] = []
    transcripts: list[dict[str, Any]] = []
    for scenario in scenarios:
        transcript = run_scenario(client, prompt, scenario)
        report = evaluate_scenario(scenario, transcript)
        reports.append(report)
        transcripts.append(transcript)

    output = {
        "prompt": args.prompt,
        "scenario_set": args.scenario_set,
        "model": client.model,
        "passed": all(report.passed for report in reports),
        "reports": [asdict(report) for report in reports],
        "transcripts": transcripts,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))

    if args.write_report:
        REPORT_DIR.mkdir(parents=True, exist_ok=True)
        path = REPORT_DIR / f"{args.prompt}-kimi-{args.scenario_set}.json"
        path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")

    return 0 if output["passed"] else 1


def run_scenario(client: KimiClient, prompt: str, scenario: dict[str, Any]) -> dict[str, Any]:
    public_context = {
        "events": scenario["public_events"],
        "rule": "两边 agent 都能看两个公开事件；每个 agent 只能看自己的 private。",
    }
    dialogue: list[dict[str, str]] = []
    turns = [
        ("A", "开场：讲清自己这边关键需求，并问一个最影响 match 的问题。"),
        ("B", "回应 A，并讲清自己这边关键需求；如有必要问一个问题。"),
        ("A", "根据公开对话补问或收束；如果事件条件已清楚，可以一句轻松闲聊。"),
        ("B", "根据公开对话补问或收束；不要继续发散。"),
    ]
    agent_outputs: list[dict[str, Any]] = []
    for side, task in turns:
        payload = {
            "mode": "agent_turn",
            "self_agent": side,
            "task": task,
            "public_context": {
                **public_context,
                "dialogue_so_far": dialogue,
            },
            "self_private": scenario["private"][side],
        }
        result = call_json(client, prompt, payload, temperature=0.2)
        message = str(result.get("message") or "").strip()
        dialogue.append({"speaker": side, "content": message})
        agent_outputs.append({"side": side, "result": result})

    judge_payload = {
        "mode": "judge",
        "public_context": public_context,
        "public_dialogue": dialogue,
    }
    judge = call_json(client, prompt, judge_payload, temperature=0.1)
    return {
        "scenario_id": scenario["id"],
        "title": scenario["title"],
        "dialogue": dialogue,
        "agent_outputs": agent_outputs,
        "judge": judge,
    }


def call_json(client: KimiClient, prompt: str, payload: dict[str, Any], temperature: float) -> dict[str, Any]:
    messages = [
        {"role": "system", "content": prompt},
        {
            "role": "user",
            "content": "请按 prompt 的 JSON 结构处理以下输入：\n" + json.dumps(payload, ensure_ascii=False, indent=2),
        },
    ]
    return client.chat_json(messages, temperature=temperature)


def evaluate_scenario(scenario: dict[str, Any], transcript: dict[str, Any]) -> ScenarioReport:
    expected = scenario["expected"]
    judge = transcript["judge"]
    failures: list[str] = []
    should_match = bool(judge.get("should_match"))
    score = safe_float(judge.get("compatibility"))
    text = json.dumps(transcript, ensure_ascii=False)

    if should_match != expected["should_match"]:
        failures.append(f"should_match expected {expected['should_match']} got {should_match}")
    if "min_score" in expected and score < float(expected["min_score"]):
        failures.append(f"score {score} below min {expected['min_score']}")
    if "max_score" in expected and score > float(expected["max_score"]):
        failures.append(f"score {score} above max {expected['max_score']}")
    for item in expected.get("must_include", []):
        if item not in text:
            failures.append(f"missing expected topic: {item}")
    for item in expected.get("must_conflict", []):
        if item not in json.dumps(judge.get("conflicts", []), ensure_ascii=False) and item not in str(judge.get("summary", "")):
            failures.append(f"missing conflict evidence: {item}")
    for item in expected.get("must_uncertain", []):
        if item not in json.dumps(judge.get("uncertainties", []), ensure_ascii=False) and item not in str(judge.get("summary", "")):
            failures.append(f"missing uncertainty evidence: {item}")
    for leak in expected.get("forbidden_leaks", []):
        if leak in public_output_text(transcript):
            failures.append(f"private leak in public output: {leak}")

    messages = [turn["content"] for turn in transcript["dialogue"]]
    long_messages = [message for message in messages if len(message) > 100]
    if long_messages:
        failures.append("agent message too long: " + " / ".join(long_messages[:2]))
    if len(transcript["dialogue"]) > 4:
        failures.append("dialogue exceeded four agent turns")
    if should_match and not str(judge.get("chatroom_carryover") or "").strip():
        failures.append("matched result missing chatroom_carryover")
    if not should_match and str(judge.get("chatroom_carryover") or "").strip():
        failures.append("rejected result should not have chatroom_carryover")
    if len(str(judge.get("chatroom_carryover") or "")) > 80:
        failures.append("chatroom_carryover too long")

    return ScenarioReport(
        scenario_id=scenario["id"],
        title=scenario["title"],
        passed=not failures,
        score=score,
        should_match=should_match,
        failures=failures,
    )


def public_output_text(transcript: dict[str, Any]) -> str:
    public = {
        "dialogue": transcript.get("dialogue"),
        "judge": transcript.get("judge"),
    }
    return json.dumps(public, ensure_ascii=False)


def safe_float(value: Any) -> float:
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return 0.0


def load_server_env() -> None:
    env_path = ROOT.parent / "dazi-server" / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_server_env()


if __name__ == "__main__":
    raise SystemExit(main())
