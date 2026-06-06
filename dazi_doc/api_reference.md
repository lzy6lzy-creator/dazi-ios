# i搭不搭 API Reference

最后更新：2026-06-05

## 1. 通用规则

生产公网入口以当前部署为准：

- 临时 IP：`http://47.103.127.95`
- 域名：`https://idabuda.com` 可用后优先使用域名

认证方式：

- 用户侧 REST API：`Authorization: Bearer <access_token>`
- 管理端 API：`Authorization: Bearer <ADMIN_TOKEN>`
- WebSocket：`/ws?token=<jwt_access_token>`
- 公开页面/表单：无认证

错误格式通常为：

```json
{"detail": "错误描述"}
```

完整 schema 以 FastAPI `/docs` 为准；本文档用于移动端和运维快速查找。

## 2. Auth

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/send-code` | 无 | 发送/模拟验证码 |
| POST | `/api/v1/auth/login` | 无 | 手机号验证码登录，首次登录自动注册 |
| POST | `/api/v1/auth/refresh` | 无 | refresh token 换 access token |

内测阶段登录受白名单和固定内测验证码控制。正式上线前切换真实短信服务。

## 3. Users / Agents / Memories

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/api/v1/users/me` | JWT | 当前用户资料 |
| PUT | `/api/v1/users/me` | JWT | 更新用户资料 |
| GET | `/api/v1/agents/me` | JWT | 当前用户的 AI 搭子经纪人资料 |
| PUT | `/api/v1/agents/me` | JWT | 更新 AI 资料 |
| GET | `/api/v1/agents/me/memories` | JWT | 当前用户 Memory 列表 |
| PATCH | `/api/v1/agents/me/memories/{memory_id}` | JWT | 更新 Memory |
| DELETE | `/api/v1/agents/me/memories/{memory_id}` | JWT | 停用/删除 Memory |

Memory 只返回给所属用户，不应暴露给对方用户。

## 4. Agent Chat

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/agent/chat` | JWT | 用户和 AI 对话，可能返回事件草稿或澄清卡片 |
| GET | `/api/v1/agent/history` | JWT | 获取 AI 对话历史 |
| DELETE | `/api/v1/agent/history` | JWT | 清空 AI 对话历史 |
| POST | `/api/v1/agent/clarification/answer` | JWT | 提交澄清卡片答案 |
| GET | `/api/v1/agent/clarification/pending` | JWT | 查询待回答澄清 |
| POST | `/api/v1/agent/edit-event/{event_id}` | JWT | 通过 AI 编辑已有事件 |

## 5. Events

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| POST | `/api/v1/events` | JWT | 创建事件 |
| GET | `/api/v1/events` | JWT | 当前用户事件列表 |
| GET | `/api/v1/events/{event_id}` | JWT | 事件详情 |
| PUT | `/api/v1/events/{event_id}` | JWT | 更新事件 |
| DELETE | `/api/v1/events/{event_id}` | JWT | 取消/删除事件 |
| POST | `/api/v1/events/{event_id}/match` | JWT | 手动触发匹配 |

创建/更新事件后，服务端负责 embedding 和匹配相关后台处理。

## 6. Chat

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/api/v1/chat/rooms` | JWT | 聊天室列表 |
| GET | `/api/v1/chat/match-requests` | JWT | 被动邀请列表 |
| POST | `/api/v1/chat/match-requests/{request_id}/respond` | JWT | 接受或拒绝被动邀请 |
| GET | `/api/v1/chat/rooms/{room_id}/messages` | JWT | 聊天室消息 |
| POST | `/api/v1/chat/rooms/{room_id}/messages` | JWT | 发送消息，支持 @AI |
| POST | `/api/v1/chat/rooms/{room_id}/close` | JWT | 关闭聊天室 |
| POST | `/api/v1/chat/rooms/{room_id}/vote` | JWT | 投“搭 / 不搭” |
| GET | `/api/v1/chat/rooms/{room_id}/vote-status` | JWT | 查看投票状态 |

## 7. WebSocket

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| WS | `/ws?token=<jwt_access_token>` | Query token | 实时消息、聊天室更新、匹配通知 |

客户端断线后应重新连接，并通过 REST 拉取历史消息补齐。

## 8. 公开页面和表单

| Method | Path | Auth | 说明 |
| --- | --- | --- | --- |
| GET | `/` | 无 | 官网/落地页 |
| GET | `/health` | 无 | 健康检查 |
| GET | `/admin` | 无页面入口，API 需 token | 管理后台页面 |
| GET | `/test` | 无 | 测试页面 |
| GET | `/match-test` | 无 | 匹配测试页面 |
| POST | `/api/v1/beta-signups` | 无 | 官网内测报名 |
| POST | `/api/v1/feedback` | 无 | 官网反馈 |

## 9. Admin

所有 `/api/admin/*` 接口均需要 `ADMIN_TOKEN`。

| Method | Path | 说明 |
| --- | --- | --- |
| GET | `/api/admin/status` | 系统状态 |
| GET | `/api/admin/users` | 用户列表 |
| DELETE | `/api/admin/users/{user_id}` | 删除测试用户 |
| GET | `/api/admin/events` | 事件列表 |
| POST | `/api/admin/events/{event_id}/reset` | 重置单个事件 |
| POST | `/api/admin/events/reset-all` | 重置所有事件 |
| GET | `/api/admin/match/preview/{event_id}` | 匹配预览 |
| POST | `/api/admin/match/event/{event_id}` | 匹配单个事件 |
| POST | `/api/admin/match/manual` | 手动匹配两个事件 |
| POST | `/api/admin/match/all` | 全量匹配 |
| POST | `/api/admin/match/run-all` | 运行匹配任务 |
| GET | `/api/admin/match-logs` | 匹配日志 |
| GET | `/api/admin/rooms` | 聊天室列表 |
| GET | `/api/admin/logs` | 后端日志 |
| DELETE | `/api/admin/logs` | 清空内存日志 |
| GET | `/api/admin/prompts` | prompt 列表 |
| GET | `/api/admin/prompts/{name}` | prompt 详情 |
| PUT | `/api/admin/prompts/{name}` | 更新 prompt |
| DELETE | `/api/admin/prompts/{name}` | 删除 prompt |
| GET | `/api/admin/beta-signups` | 内测报名列表 |
| PATCH | `/api/admin/beta-signups/{signup_id}/status` | 更新报名状态 |
| POST | `/api/admin/beta-signups/{signup_id}/invite-internal` | 邀请加入内测白名单 |
| GET | `/api/admin/beta-signups.csv` | 导出报名 |
| GET | `/api/admin/feedback` | 反馈列表 |
| PATCH | `/api/admin/feedback/{feedback_id}/status` | 更新反馈状态 |
| GET | `/api/admin/feedback.csv` | 导出反馈 |
| POST | `/api/admin/test/generate` | 生成测试数据 |
| DELETE | `/api/admin/test/cleanup` | 清理测试数据 |
| GET | `/api/admin/test/match-preview-all` | 全量匹配预览 |
| GET | `/api/admin/test/stats` | 测试统计 |

