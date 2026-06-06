# Room Agent Lab

`room-agent-lab` 用真实 Kimi 测试聊天室内 agent 被用户 `@` 后的回复策略。

重点验证：

- 两边公开事件、A2A 对话、匹配摘要、聊天室最近消息对双方 agent 可见。
- 每个 agent 只能看到自己用户的 profile/memory/非事件信息。
- 私有信息只能转成和本次活动直接相关的条件，不能原文泄露。
- 被 `@` 后快速、清晰地推进聊天室协商，不做长篇规划，不替用户承诺。

## 运行

```bash
PYTHONPATH=src python3 -m room_agent_lab.run_lab --prompt room_agent_v3 --scenario-set core --write-report
```

Kimi key 优先从环境变量读取：`KIMI_API_KEY`、`MOONSHOT_API_KEY` 或 `LLM_API_KEY`。脚本也会尝试读取相邻服务端仓库的 `.env`。
