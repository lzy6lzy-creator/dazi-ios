# 客户端设计

最后更新：2026-08-29

## 1. 信息架构

iOS 当前包含四个核心区：

| 区域 | 主要任务 |
| --- | --- |
| AI | 创建活动、结构化 Clarify、编辑活动、继续对话 |
| 活动 | 左右切换“我的活动”和匿名活动广场，支持筛选排序 |
| 聊天室 | 处理匹配摘要、待确认邀请、双方投票、消息沟通 |
| 我的 | 用户资料、AI 资料、Memory、设置、退出 |

## 2. 体验原则

- AI 是活动入口，不是泛聊天入口。
- 活动页是任务看板，不是普通列表。
- 聊天室是活动确认场，不是普通 IM。
- 登录要明确已注册、白名单、新用户免邀请码和需邀请码四种状态；非白名单始终使用动态验证码。
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

当前实现：

- access/refresh token 存在 Keychain，首次读取会迁移旧 `UserDefaults` 值。
- WebSocket 使用 Bearer header，断线后指数退避重连，并忽略旧连接的延迟回调。
- APNs 负责真机后台和前台通知；模拟器使用本地通知回退，避免真机重复横幅。
- iOS 26 定位反查使用 MapKit；定位文本按“当前位置优先，用户明确表述覆盖”传给 Agent。
- 注册工作内容使用 1–5 项动作多选；底栏展示当前 Agent 名称和头像。
- 活动评价保存到后端；双方都结束后才关闭共享聊天室，评分和评论只进入自己的反馈记录与 Memory。

仍需补齐：

- 自定义头像和活动相册缺少服务端上传/同步，当前图片主要留在本机。
- `GalleryStore` 将照片编码进单个 JSON 文件并同步读写，图片增多后会阻塞主线程，应改为独立文件和元数据索引。
- TestFlight 构建必须真机跑登录、邀请码、定位、创建活动、匹配、推送、聊天室、注销和退出重登。

## 4. Android（当前不在发布范围）

主要代码：

- `dazi-android/app/src/main/java/com/dazi/app/ui/`
- `dazi-android/app/src/main/java/com/dazi/app/viewmodel/`
- `dazi-android/app/src/main/java/com/dazi/app/data/`

Android 仓库保留了历史实现和大量尚未整理的本地改动。本轮审查、清理、文档结论和发布验证均不覆盖 Android；重新启动 Android 开发时，应先独立审查其脏工作区和 API 差异，不能默认与 iOS 同步。

## 5. 协议一致性

未来恢复多端开发时需要保持一致：

- Event 状态枚举和展示文案。
- 被动邀请入口和接受/拒绝行为。
- 聊天室投票状态和关闭状态。
- Message DTO 中用户消息、AI 消息、系统消息的区分。
- Agent Memory 的可见性和编辑/停用入口。

接口清单见 [API Reference](../api_reference.md)。
