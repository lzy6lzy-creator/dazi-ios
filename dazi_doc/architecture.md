# i搭不搭 系统架构

最后更新：2026-08-29

## 1. 总览

```text
iOS（当前产品主线）
  -> HTTP API / WebSocket
FastAPI Backend
  -> PostgreSQL + pgvector
  -> Redis
  -> Kimi LLM API
  -> sentence-transformers embedding
```

当前是 SwiftUI iOS 客户端 + FastAPI 单体后端的内测架构。后端负责认证/邀请码、用户资料、AI 对话与 Clarify、事件、匹配、聊天室、APNs、管理后台和静态页面。Android 仓库保留，但目前不做功能同步或发布验证。

## 2. 仓库

| 仓库 | 路径 | 说明 |
| --- | --- | --- |
| iOS | `/Users/wuxing/Desktop/dazi/dazi` | SwiftUI 客户端，当前文档也放在此仓库 |
| Android | `/Users/wuxing/Desktop/dazi/dazi-android` | 保留的 Kotlin/Compose 客户端，当前不在发布范围 |
| 后端 | `/Users/wuxing/Desktop/dazi/dazi/dazi-server` | FastAPI、PostgreSQL、Redis、Docker 部署 |

顶层 `/Users/wuxing/Desktop/dazi` 不是 git 仓库。

## 3. 后端模块

| 模块 | 代码路径 | 职责 |
| --- | --- | --- |
| API 路由 | `dazi-server/app/api/` | auth、users、events、agent_chat、chat、admin、ws |
| ORM 模型 | `dazi-server/app/models/` | user、event、chat、prompt、beta_signup、site_feedback |
| 核心配置 | `dazi-server/app/core/` | settings、database、redis、security、log_buffer |
| LLM | `dazi-server/app/services/agent_server.py` | Kimi/兼容 Chat Completions 的统一流式客户端 |
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
- `event_feedbacks`：用户对自己事件的体验评分、搭子评分和私有评论。
- `event_gallery_items`：已完成事件的照片 URL、展示开关和更新时间。
- `chat_rooms`、`messages`、`passive_match_requests`：聊天室、消息、被动邀请。
- `match_logs`、`match_blocklists`：匹配日志和黑名单。
- `prompt_templates`：管理后台可编辑 prompt。
- `beta_signups`、`site_feedback`：官网收集的内测报名和反馈。
- `invitation_programs`、`signup_admissions`、`user_invitation_accounts`、`invitation_ledgers`：注册准入和邀请码账本。
- `push_device_tokens`：iOS APNs token 与环境。
- `service_reminders`：服务到期、核查和余额提醒。
- `uploads/avatars`：用户与 Agent 的持久化图片头像；数据库只保存媒体 URL。
- `uploads/gallery`：活动相册原图；通过鉴权 API 按公开主页设置读取，不由 Nginx 公开暴露。

事件的新写入只使用 `location`。`events.city` 和 `city_normalized` 暂时保留用于旧数据兼容，不应作为新业务槽位。

## 5. 关键流程

### 登录

```text
registration-policy -> send-code -> admission token -> login -> JWT -> users/me / agents/me
```

动态验证码由阿里云 PNVS 提供。新用户先经过开放/邀请码准入；服务端白名单用户可额外使用固定测试码，非白名单用户只能用动态码。iOS 将 access/refresh token 存入 Keychain。

### 活动创建

```text
用户输入或 Clarify 答案 -> Conversation Orchestrator -> reply + action -> 用户确认 -> Event -> embedding -> 匹配任务
```

主对话和 Clarify 后续共用同一个编排器；不存在独立 `draft_reply` 调用。服务端解析模型标签，确定性合并卡片答案，并只在用户确认后创建 Event。

### 匹配

```text
pending Event
  -> 状态/时间/地点/事件维度黑名单硬过滤
  -> pgvector TopK 召回
  -> A2A 精排
  -> 创建聊天室或进入下一轮
```

主动匹配失败多轮后进入被动邀请，不直接创建聊天室。

### 聊天室

```text
Chat Room -> REST 历史消息 -> WebSocket 实时消息 -> APNs -> 投票/关闭/事件屏蔽
```

用户消息通过 REST 写库，同时广播 WebSocket，并给离线/后台设备发送 APNs。@AI 时后端生成 AI 回复并广播。iOS WebSocket 使用 Bearer header，断线后指数退避重连。

## 6. 部署

生产服务器是 `47.103.127.95`，远端目录 `/opt/dazi-server`。生产 compose 中 API 只发布在服务器本机 `127.0.0.1:8000`，公网流量应经 Nginx 暴露。

详情见 [部署与运维](ops/deployment.md)。

## 7. 当前技术债

- 聊天室列表存在逐房间/逐成员查询，房间规模增长前应改为批量查询或 eager loading。
- WebSocket 连接管理仍是单进程内存实现，多 worker 前需要 Redis Pub/Sub 或独立消息层。
- 定时匹配任务仍在 API 进程内，正式生产建议拆独立 worker。
- 监控、备份、告警和 DB 迁移流程需要生产化。
- 当前 `/health` 只表示 API 进程存活，不检查 PostgreSQL、Redis、LLM 或 APNs 可用性。
