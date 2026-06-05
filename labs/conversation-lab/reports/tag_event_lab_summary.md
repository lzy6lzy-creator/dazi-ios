# Tag-based Event Extraction Streaming Lab

Date: 2026-06-05

## Goal

Evaluate whether the event extraction prompt can move from JSON-only output to a stream-friendly tag format:

```xml
<city>上海</city>
<activity>羽毛球</activity>
<start_time>2026-04-18 19:00</start_time>
<end_time>2026-04-18 21:00</end_time>
<preferences>中等水平，想认真打</preferences>
```

The product path still uses JSON. This lab only tests an isolated prompt and runner in `conversation-lab`.

## Command

```bash
PYTHONPATH=src python3 -m conversation_lab.tag_event_lab --provider all --write-report
```

The runner uses `stream=true` by default and records first token time, first complete tag time, total response time, format compliance, and field score.

## Three-run Aggregate

| Model | Cases | Format OK | Passed | Avg field score | Avg first token | Avg first complete tag | Avg total |
|-------|-------|-----------|--------|-----------------|-----------------|------------------------|-----------|
| kimi-k2.5 | 12 | 12 | 12 | 1.0000 | 1.0790s | 1.0792s | 2.3894s |
| deepseek-v4-flash | 12 | 12 | 9 | 0.9375 | 0.6549s | 0.6810s | 0.9871s |
| deepseek-v4-pro | 12 | 12 | 12 | 1.0000 | 1.0155s | 1.0689s | 1.6524s |

## Findings

- Both models can follow the tag-only format under streaming. No JSON braces, Markdown fences, or unknown tags appeared in the three runs.
- Kimi was more reliable on content extraction in this suite: 12/12 pass.
- DeepSeek V4 Flash was much faster, but missed the `徐汇` location in the injection case in all three runs. It preserved format but reduced preferences to `预算 100 以内`.
- DeepSeek V4 Pro passed all cases and retained `徐汇` in the injection case across three runs. It was slower than Flash but still faster than Kimi on total response time.
- Tag-based streaming is feasible: the first complete tag arrived at about the same time as first token. Flash averaged about 0.68s to first complete tag, Pro about 1.07s, and Kimi about 1.08s.

## Recommendation

For product behavior, keep JSON as the canonical internal contract until the tag parser has the same validation and fallback guarantees as `chat_json`.

For UI streaming, tag output is a good candidate for an experiment because a client can render field-by-field before the full extraction is complete. If DeepSeek V4 Flash is used, tighten the prompt around location retention or add a deterministic post-check that requires explicit city/area phrases from the user input to appear in either `city` or `preferences`.
