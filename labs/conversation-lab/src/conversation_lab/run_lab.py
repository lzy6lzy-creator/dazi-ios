from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .engine import ConversationEngine
from .evaluator import evaluate_transcript
from .scenarios import load_scenarios


ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = ROOT / "reports"


def main() -> int:
    parser = argparse.ArgumentParser(description="Run standalone conversation lab scenarios.")
    parser.add_argument("--prompt", default="orchestrator_v2")
    parser.add_argument("--backend", default="rule", choices=["rule", "kimi"])
    parser.add_argument("--scenario-set", default="core")
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()

    engine = ConversationEngine.from_prompt_name(args.prompt, backend=args.backend)
    results = []
    transcripts = []
    for scenario in load_scenarios(args.scenario_set):
        transcript = engine.run_scenario(scenario)
        report = evaluate_transcript(scenario, transcript)
        results.append(report)
        transcripts.append({
            "scenario_id": scenario.id,
            "turns": [
                {"role": turn.role, "content": turn.content, "decision": turn.decision}
                for turn in transcript.turns
            ],
            "final_draft": transcript.final_draft,
            "published": transcript.published,
        })

    output = {
        "prompt": args.prompt,
        "backend": args.backend,
        "passed": all(report.passed for report in results),
        "results": [asdict(report) for report in results],
        "transcripts": transcripts,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))

    if args.write_report:
        REPORT_DIR.mkdir(parents=True, exist_ok=True)
        path = REPORT_DIR / f"{args.prompt}-{args.backend}-{args.scenario_set}.json"
        path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")

    return 0 if output["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
