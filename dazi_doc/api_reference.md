# i搭不搭 API Reference

最后更新：2026-08-29

## 1. 通用规则

生产公网入口：`https://idabuda.com`。

认证方式：

- 用户侧 REST API：`Authorization: Bearer <access_token>`。
- 管理端 API：`Authorization: Bearer <ADMIN_TOKEN>`。
- WebSocket：连接 `/ws` 时发送 `Authorization: Bearer <access_token>`；query token 只为旧客户端临时兼容。
- 公开页面和表单：无认证。

错误通常使用 FastAPI 格式：

```json
{"detail": "错误描述"}
```

完整请求和响应 schema 以 FastAPI `/docs` 为准。用户输入已设置长度和数量边界，Agent/聊天室正文最大 4000 字符，消息历史单次最多读取 200 条。

## 2. Auth 与注册准入

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/api/v1/auth/registration-policy` | 无 | 当前开放人数、邀请码和 iOS 分发策略 |
| POST | `/api/v1/auth/send-code` | 无 | 校验注册准入并发送 PNVS 动态验证码 |
| POST | `/api/v1/auth/login` | 无 | 验证码登录；首次登录消费注册凭证并创建用户 |
| POST | `/api/v1/auth/refresh` | 无 | refresh token 换取新 token |

已注册用户正常走动态验证码。服务端白名单用户还可使用后端配置的固定测试码；非白名单用户只能使用动态验证码。新用户是否需要邀请码由 `invitation_programs.registration_mode` 决定。

## 3. Users、Agents、Memories

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/api/v1/users/me` | JWT | 当前用户资料 |
| PUT | `/api/v1/users/me` | JWT | 更新用户资料 |
| DELETE | `/api/v1/users/me` | JWT | 注销账号并清除事件及关联数据 |
| PUT | `/api/v1/users/me/avatar` | JWT | 上传当前用户头像（JPEG/PNG/WebP，最大 1MB） |
| DELETE | `/api/v1/users/me/avatar` | JWT | 删除当前用户图片头像，回退 Emoji |
| GET | `/api/v1/users/{user_id}/profile` | JWT | 查看其他用户公开资料，过往事件服从可见性设置 |
| GET | `/api/v1/agents/me` | JWT | 当前用户的 AI 搭子经纪人资料 |
| PUT | `/api/v1/agents/me` | JWT | 更新 AI 名称、Emoji 和性格 |
| PUT | `/api/v1/agents/me/avatar` | JWT | 上传当前 AI 头像 |
| DELETE | `/api/v1/agents/me/avatar` | JWT | 删除当前 AI 图片头像 |
| GET | `/api/v1/agents/me/memories` | JWT | 当前用户 Memory 列表 |
| PATCH | `/api/v1/agents/me/memories/{memory_id}` | JWT | 更新 Memory |
| DELETE | `/api/v1/agents/me/memories/{memory_id}` | JWT | 停用 Memory |

Memory 和 Agent 配置不会出现在其他用户的公开主页。

头像文件通过 `/media/avatars/*` 公开读取，文件名包含内容哈希用于缓存刷新；用户 Emoji 使用独立 `avatar_emoji` 字段，不与图片 URL 混用。

## 4. Agent Chat 与 Clarify

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/agent/chat` | JWT | 非流式主对话编排 |
| POST | `/api/v1/agent/chat/stream` | JWT | SSE 流式主对话编排 |
| GET | `/api/v1/agent/history?limit=50` | JWT | 获取主对话历史 |
| DELETE | `/api/v1/agent/history` | JWT | 开启新会话，不物理删除审计历史 |
| POST | `/api/v1/agent/clarification/answer` | JWT | 提交澄清卡片并继续主编排器 |
| POST | `/api/v1/agent/clarification/answer/stream` | JWT | 流式提交澄清卡片 |
| GET | `/api/v1/agent/clarification/pending` | JWT | 恢复仍有效的澄清卡片 |
| POST | `/api/v1/agent/edit-event/{event_id}` | JWT | 进入事件编辑对话 |

普通输入和 Clarify 答案都由 `conversation_orchestrator` 输出 `reply + action`。系统不存在独立 `draft_reply` 模型调用。

## 5. Events

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/events` | JWT | 创建事件 |
| GET | `/api/v1/events` | JWT | 当前用户事件列表 |
| GET | `/api/v1/events/plaza` | JWT | 匿名活动广场，排除自己的事件 |
| GET | `/api/v1/events/{event_id}` | JWT | 当前用户事件详情 |
| PUT | `/api/v1/events/{event_id}` | JWT | 更新待匹配事件 |
| DELETE | `/api/v1/events/{event_id}` | JWT | 取消事件 |
| POST | `/api/v1/events/{event_id}/match` | JWT | 手动触发匹配 |
| POST | `/api/v1/events/{event_id}/feedback` | JWT | 结束自己的活动并幂等保存体验/搭子评价 |

事件地点的唯一业务字段是 `location`。请求中的旧 `city` 字段只作为兼容输入合并到 `location`，新建和更新事件不会再写 `events.city`。

评价后只把当前用户的事件标为 `completed`；双方关联事件都完成（或另一方已取消）后才关闭聊天室。评价同时更新当前用户自己的 feedback Memory，不会向对方公开。

## 6. Chat Rooms

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/api/v1/chat/rooms` | JWT | 聊天室列表、成员、最新消息和未读状态 |
| GET | `/api/v1/chat/match-requests` | JWT | 被动邀请列表 |
| POST | `/api/v1/chat/match-requests/{request_id}/respond` | JWT | 接受或拒绝被动邀请 |
| GET | `/api/v1/chat/rooms/{room_id}/messages` | JWT | 分页获取聊天室消息 |
| POST | `/api/v1/chat/rooms/{room_id}/read` | JWT | 更新已读时间 |
| POST | `/api/v1/chat/rooms/{room_id}/messages` | JWT | 发送消息，支持 @AI |
| POST | `/api/v1/chat/rooms/{room_id}/close` | JWT | 关闭聊天室 |
| POST | `/api/v1/chat/rooms/{room_id}/vote` | JWT | 投“搭 / 不搭” |
| GET | `/api/v1/chat/rooms/{room_id}/vote-status` | JWT | 查看双方投票状态 |

## 7. Notifications、Invitations、Location

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/notifications/device-token` | JWT | 注册 iOS APNs device token |
| DELETE | `/api/v1/notifications/device-token` | JWT | 停用当前账号的 device token |
| GET | `/api/v1/invitations/me` | JWT | 当前邀请码、余额和里程碑 |
| GET | `/api/v1/invitations/{code}/status` | JWT | 检查邀请码状态 |
| POST | `/api/v1/location/verify` | JWT | 提交启动城市定位验证 |

真实设备的新聊天室和新消息通知由 APNs 负责；WebSocket 用于应用在线时刷新状态。模拟器保留本地通知作为调试回退。

## 8. WebSocket

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| WS | `/ws` | Bearer header | 新消息、事件状态、聊天室、邀请和 Memory 更新 |

iOS 客户端使用当前 access token 建立连接，断线后指数退避重连。恢复连接后仍通过 REST 历史接口补齐可能遗漏的数据。

## 9. 公开页面和表单

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/` | 无 | 官网 |
| GET | `/health` | 无 | 进程健康检查 |
| GET | `/admin` | 页面无认证，后台 API 需 token | 统一管理后台 |
| GET | `/match-test` | 页面无认证，后台 API 需 token | 统一后台测试实验页别名 |
| GET | `/test` | 无 | 服务器本机综合 API 调试页 |
| POST | `/api/v1/beta-signups` | 无 | 官网内测报名 |
| POST | `/api/v1/feedback` | 无 | 官网反馈 |

## 10. Admin

所有 `/api/admin/*` 接口均需要 `ADMIN_TOKEN`。统一后台覆盖：

- 系统状态、用户、事件、聊天室和日志。
- 单事件预览、匹配详情、手动/批量匹配、重置和匹配日志。
- Prompt 查看、覆盖和恢复默认值。
- TestFlight 报名、邀请、App Store Connect 状态同步和 CSV 导出。
- 官网反馈查看、状态更新和 CSV 导出。
- 服务到期/核查/余额提醒的增删改查、在线核查和周期顺延。
- 测试用户生成、清理、统计和批量匹配预览。

后台接口的精确清单以 `/docs` 为准，管理端文档不复制每个参数，避免与实现再次漂移。
