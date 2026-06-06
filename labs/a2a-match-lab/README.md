# A2A Match Lab

`a2a-match-lab` is a standalone prompt lab for the `i搭不搭` A2A matching flow.
It does not import or modify server, iOS, or Android runtime code.

The lab tests an asymmetric A2A design:

- Both agents can see both public events.
- Each agent can see only its own user's profile and memory.
- The event topic may have multiple short turns.
- At most one brief off-event chat moment is allowed after event needs are clear.
- The full A2A dialogue is preserved and summarized for the matched room.
- Explicit conflicts must block matching regardless of the numeric score.

## Layout

- `prompts/a2a_match_v1.md`: first asymmetric prompt draft.
- `prompts/a2a_match_v2.md`: stricter conflict and scoring prompt.
- `prompts/a2a_match_v3.md`: concise multi-turn candidate prompt.
- `prompts/a2a_match_v4.md`: privacy-leak review prompt.
- `prompts/a2a_match_v5.md`: first unknown-field review prompt.
- `prompts/a2a_match_v6.md`: final candidate prompt after hard unknown-field review.
- `scenarios/core.json`: Kimi evaluation scenarios.
- `src/a2a_match_lab/run_lab.py`: real Kimi runner and evaluator.
- `reports/`: generated JSON and Chinese summary reports.

## Run

From this directory:

```bash
export $(grep -v '^#' ../dazi-server/.env | xargs)
PYTHONPATH=src python3 -m a2a_match_lab.run_lab --prompt a2a_match_v6 --scenario-set core --write-report
```

The runner calls the configured Moonshot/Kimi-compatible chat completion API.
