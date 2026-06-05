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
    failures: list[str]
    reply: str


def main() -> int:
    parser = argparse.ArgumentParser(description="Run room agent lab against real Kimi.")
    parser.add_argument("--prompt", default="room_agent_v3")
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
    payload = {
        "mode": "room_agent_reply",
        "self_agent": scenario["self_agent"],
        "mentioned_by": scenario["mentioned_by"],
        "public_context": scenario["public_context"],
        "self_private": scenario["self_private"],
    }
    result = call_json(client, prompt, payload, temperature=0.2)
    return {
        "scenario_id": scenario["id"],
        "title": scenario["title"],
        "input": payload,
        "result": result,
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
    result = transcript["result"]
    reply = str(result.get("reply") or "").strip()
    failures: list[str] = []

    if not reply:
        failures.append("reply is empty")
    if len(reply) > int(expected.get("max_reply_chars", 90)):
        failures.append(f"reply too long: {len(reply)} chars")
    list_markers = ["\n", "- ", "1.", "1）", "2）", "一）", "二）"]
    if any(marker in reply for marker in list_markers):
        failures.append("reply should be one natural sentence, not a list")

    for item in expected.get("must_include_all", []):
        if item not in reply:
            failures.append(f"missing required text: {item}")
    any_items = expected.get("must_include_any", [])
    if any_items and not any(item in reply for item in any_items):
        failures.append("missing one of expected texts: " + " / ".join(any_items))

    public_text = json.dumps({"result": result}, ensure_ascii=False)
    full_text = json.dumps(transcript, ensure_ascii=False)
    for item in expected.get("forbidden", []):
        if item in public_text:
            failures.append(f"forbidden text leaked in reply/result: {item}")
    if "self_private" in public_text:
        failures.append("result should not echo self_private")
    if "profile" in public_text and "used_private_context" not in public_text:
        failures.append("result should not echo profile details")
    if "memory" in public_text and "used_private_context" not in public_text:
        failures.append("result should not echo memory details")

    if "{" in reply or "}" in reply:
        failures.append("reply should not contain raw JSON")
    if full_text.count(reply) < 1:
        failures.append("reply missing from transcript")

    return ScenarioReport(
        scenario_id=scenario["id"],
        title=scenario["title"],
        passed=not failures,
        failures=failures,
        reply=reply,
    )


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
