# i搭不搭 系统架构

最后更新：2026-06-05

## 1. 总览

```text
iOS / Android
  -> HTTP API / WebSocket
FastAPI Backend
  -> PostgreSQL + pgvector
  -> Redis
  -> Kimi LLM API
  -> sentence-transformers embedding
```

当前是单体后端 + 双移动端客户端的 MVP 架构。后端负责认证、用户资料、AI 对话、事件、匹配、聊天室、管理后台和静态页面。iOS 和 Android 共享同一套 REST API 与 WebSocket。

## 2. 仓库

| 仓库 | 路径 | 说明 |
| --- | --- | --- |
| iOS | `/Users/wuxing/Desktop/dazi/dazi` | SwiftUI 客户端，当前文档也放在此仓库 |
| Android | `/Users/wuxing/Desktop/dazi/dazi-android` | Kotlin/Compose 客户端 |
| 后端 | `/Users/wuxing/Desktop/dazi/dazi-server` | FastAPI、PostgreSQL、Redis、Docker 部署 |

顶层 `/Users/wuxing/Desktop/dazi` 不是 git 仓库。

## 3. 后端模块

| 模块 | 代码路径 | 职责 |
| --- | --- | --- |
| API 路由 | `dazi-server/app/api/` | auth、users、events、agent_chat、chat、admin、ws |
| ORM 模型 | `dazi-server/app/models/` | user、event、chat、prompt、beta_signup、site_feedback |
| 核心配置 | `dazi-server/app/core/` | settings、database、redis、security、log_buffer |
| LLM | `dazi-server/app/services/llm_service.py` | Kimi/兼容 OpenAI Chat Completions 调用 |
| Prompt | `dazi-server/app/services/prompt_builder.py` | 系统 prompt 和 prompt 模板读取 |
| Memory | `dazi-server/app/services/memory_service.py` | 长期记忆写入、查重、证据和摘要 |
| Embedding | `dazi-server/app/services/embedding_service.py` | 事件向量生成 |
| Matching | `dazi-server/app/services/matching_service.py` | 主动匹配、A2A、聊天室创建 |
| Passive Matching | `dazi-server/app/services/passive_matching_service.py` | 被动邀请候选和请求 |
| Location | `dazi-server/app/services/location_normalizer.py`、`location_policy.py` | 地点解析和相容性判断 |
| Scheduler | `dazi-server/app/services/scheduler.py` | 周期任务入口 |

## 4. 数据模型

核心表：

- `users`：用户资料、手机号、头像、兴趣、城市。
- `agents`：每个用户的 AI 搭子经纪人配置。
- `agent_chat_messages`：用户和 AI 的对话历史。
- `agent_memories`、`event_memories`、`memory_evidence`：分层记忆和证据。
- `events`：活动意图、结构化字段、状态、向量、匹配轮次。
- `chat_rooms`、`messages`、`passive_match_requests`：聊天室、消息、被动邀请。
- `match_logs`、`match_blocklists`：匹配日志和黑名单。
- `prompt_templates`：管理后台可编辑 prompt。
- `beta_signups`、`site_feedback`：官网收集的内测报名和反馈。

## 5. 关键流程

### 登录

```text
send-code -> login -> JWT -> users/me / agents/me
```

内测阶段验证码和白名单由服务端环境变量/文件控制。正式上线前应接入真实短信服务。

### 活动创建

```text
用户输入 -> Agent Chat -> 澄清/草稿 -> 用户确认 -> Event -> embedding -> 匹配任务
```

事件草稿来自 AI 输出和服务端解析。服务端会做 JSON 提取、时间推断、字段兜底和 embedding 生成。

### 匹配

```text
pending Event
  -> 状态/时间/地点/黑名单硬过滤
  -> pgvector TopK 召回
  -> A2A 精排
  -> 创建聊天室或进入下一轮
```

主动匹配失败多轮后进入被动邀请，不直接创建聊天室。

### 聊天室

```text
Chat Room -> REST 历史消息 -> WebSocket 实时消息 -> 投票/关闭/黑名单
```

用户消息通过 REST 写库，同时广播 WebSocket。@AI 时后端生成 AI 回复并广播。

## 6. 部署

生产服务器是 `47.103.127.95`，远端目录 `/opt/dazi-server`。生产 compose 中 API 只发布在服务器本机 `127.0.0.1:8000`，公网流量应经 Nginx 暴露。

详情见 [部署与运维](ops/deployment.md)。

## 7. 当前技术债

- 正式短信、HTTPS/WSS、App Store 资料仍未完全收口。
- WebSocket 连接管理仍是单进程内存实现，多 worker 前需要 Redis Pub/Sub 或独立消息层。
- 定时匹配任务仍在 API 进程内，正式生产建议拆独立 worker。
- 监控、备份、告警和 DB 迁移流程需要生产化。
- iOS/Android token 安全存储仍需最终确认。

