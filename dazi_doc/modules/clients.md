# 客户端设计

最后更新：2026-06-05

## 1. 信息架构

iOS 和 Android 共享四个核心区：

| 区域 | 主要任务 |
| --- | --- |
| AI | 创建活动、编辑活动、查看正在推进事项、继续对话 |
| 活动 | 查看待匹配、已匹配、已取消/结束的事件 |
| 聊天室 | 处理匹配摘要、待确认邀请、双方投票、消息沟通 |
| 我的 | 用户资料、AI 资料、Memory、设置、退出 |

## 2. 体验原则

- AI 是活动入口，不是泛聊天入口。
- 活动页是任务看板，不是普通列表。
- 聊天室是活动确认场，不是普通 IM。
- 内测登录要明确白名单和验证码状态，避免用户误以为正式短信已接入。
- UI 文案使用 `AI` 或 `你的 AI 搭子经纪人`，不在公共文档和设计稿里绑定具体 persona。

## 3. iOS

主要代码：

- `dazi/Views/AgentChat/AgentChatView.swift`
- `dazi/Views/Events/EventListView.swift`
- `dazi/Views/Events/EventDetailView.swift`
- `dazi/Views/ChatRoom/ChatRoomListView.swift`
- `dazi/Views/ChatRoom/ChatRoomDetailView.swift`
- `dazi/Views/Profile/ProfileView.swift`
- `dazi/Services/APIClient.swift`
- `dazi/Services/DataStore.swift`
- `dazi/Services/WebSocketService.swift`

当前重点：

- 保持活动创建、编辑、聊天室投票和被动邀请链路可用。
- token 安全存储需要从 `UserDefaults` 迁移到 Keychain。
- TestFlight 前必须真机跑登录、创建活动、匹配、聊天室、退出重登。

## 4. Android

主要代码：

- `dazi-android/app/src/main/java/com/dazi/app/ui/`
- `dazi-android/app/src/main/java/com/dazi/app/viewmodel/`
- `dazi-android/app/src/main/java/com/dazi/app/data/`

当前状态：

- 第一轮主界面改版已完成。
- 活动列表/详情、聊天室列表/详情、个人页、登录和弹窗已对齐 iOS 主流程。
- `testDebugUnitTest`、`assembleDebug`、`installDebug` 曾通过；正式发包前仍需重新跑。

当前重点：

- token 迁移到加密存储。
- HTTPS/WSS 域名切换后移除 cleartext 放行。
- 真机截图和输入法、权限、WebSocket 断线重连状态复核。

## 5. 协议一致性

两端需要保持一致：

- Event 状态枚举和展示文案。
- 被动邀请入口和接受/拒绝行为。
- 聊天室投票状态和关闭状态。
- Message DTO 中用户消息、AI 消息、系统消息的区分。
- Agent Memory 的可见性和编辑/停用入口。

接口清单见 [API Reference](../api_reference.md)。

