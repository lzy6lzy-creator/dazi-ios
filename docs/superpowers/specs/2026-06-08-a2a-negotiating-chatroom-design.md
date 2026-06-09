# A2A 协商聊天室设计

## 目标

在 A2A 匹配过程中增加一个第一阶段的聊天室体验。用户可以观看 AI 与 AI 的协商过程，此时对方用户保持匿名。用户也可以发言，但只能对自己的 agent 说话；这些补充会影响当前这一场 A2A 协商。

## 产品语义

聊天室增加三个阶段：

- `a2a_negotiating`：A2A 协商中。候选用户匿名。用户可以观看公开的 agent 协商。用户输入是给自己 agent 的私有补充，并会影响当前协商。
- `matched`：A2A 匹配成功。房间变成正常聊天室。解除候选用户匿名。双方用户可以正常互相发言。
- `closed`：A2A 失败、输给其他候选，或房间因其他原因结束。

当向量召回把 Top3 候选送入 A2A 时，产品上可以同时展示最多 3 个独立的 `a2a_negotiating` 协商聊天室。每个房间只绑定一组 source event 和 candidate event。用户在其中一个协商聊天室里的补充，不能影响另外两个协商聊天室。

## 现有上下文

当前后端大致已有这条匹配链路：

1. Event 进入匹配。
2. 向量召回和策略过滤选出候选窗口。
3. Top 候选进入 A2A 评估。
4. 提交最终 winner。
5. 创建 `ChatRoom`，并写入 `match_summary` 和 `agent_dialogue`。

当前 iOS 聊天室 UI 默认房间已经匹配成功。它会展示匹配摘要，可选展示 agent 对话，并且只要 `isActive` 为 true 就允许普通公开用户消息。

## 推荐架构

复用现有 `ChatRoom` 模型，不单独新建一套 A2A Session 模型。

在现有聊天室层增加阶段和可见性语义：

- `chat_rooms.phase`：`a2a_negotiating`、`matched` 或 `closed`。
- `chat_rooms.a2a_candidate_rank`：当前匹配窗口中的候选排名，用于展示“匿名候选 1/2/3”。
- `chat_rooms.a2a_result`：可选结果原因，例如 `matched`、`rejected`、`lost_to_other_candidate` 或 `superseded`。
- `chat_messages.visibility`：`public_room`、`private_to_agent` 或 `system`。
- `chat_messages.recipient_user_id`：用于给自己 agent 的私有消息，确保只有发送者和自己的 agent 能看到。

具体数据库字段名可以在实现时微调，但行为契约应保持稳定。

## 后端流程

### 创建协商聊天室

当 Top3 候选进入 A2A 时，在 A2A 评估开始前或评估过程中，为每个候选 pair 创建一个 `a2a_negotiating` 房间。

每个协商聊天室应包含：

- 双方 user 成员。
- 双方 agent 成员。
- `event_id_a` 和 `event_id_b`。
- 候选排名。
- 一条说明当前阶段的系统消息。
- A2A 过程中产生的公开 agent 消息。

创建房间时可以通知双方用户，但通知文案必须明确这是 AI 协商阶段，而不是已经匹配成功。

### A2A 阶段的用户输入

当房间处于 `a2a_negotiating` 阶段时：

- `POST /rooms/{room_id}/messages` 不能创建普通公开用户消息。
- 消息应以私有可见性保存，只绑定当前用户和自己的 agent。
- 消息不能广播给对方用户。
- 原文不能直接暴露给对方 agent。
- 发送者自己的 agent 可以在下一轮 A2A 中使用这条内容。
- 如果 agent 要对外表达这条内容，必须转成和本次活动相关的公开条件，不能不必要地引用私有原文。

### A2A agent 发言

A2A 评估需要能读取当前房间内对应用户侧的私有补充。每个协商聊天室都有自己的补充上下文，因此 Top3 房间之间互不影响。

公开 agent 发言应作为 `public_room` 消息保存，`sender_type` 为 `agent`，这样双方用户都能观看协商过程。

### 匹配成功

当某个协商聊天室成功匹配：

- 将这个房间切到 `matched`。
- 将双方 event 标记为 matched。
- 写入最终 `match_summary` 和 `agent_dialogue`。
- 添加一条系统消息，说明 AI 协商已匹配成功，房间现在开放正常聊天。
- 在 room API 中解除对方用户匿名，返回真实资料。
- 开启普通公开用户消息。
- 用“匹配成功”的文案通知双方用户。

所有涉及任一已匹配 event 的其他 `a2a_negotiating` 房间都必须关闭，结果标记为 `lost_to_other_candidate` 或 `superseded`。这些房间应展示类似系统消息：`已匹配到其他搭子，本次 AI 协商结束。`

### 匹配失败

如果某个 A2A 房间失败，且没有提交匹配：

- 将房间切到 `closed`。
- 保留公开 A2A 协商记录，以及发送者自己的私有补充。
- 不解除匿名，不暴露候选用户真实身份。
- 添加一条系统消息，说明这个候选没有匹配成功。

如果所有候选都失败，event 按现有匹配重试规则回到 pending。

## 可见性与隐私规则

在 `a2a_negotiating` 阶段：

- 对方用户显示为匿名。
- 对方用户的姓名、头像、简介、性别、年龄、城市和 profile 字段都隐藏。
- 已经属于匹配上下文的公开 event 字段可以展示。
- 公开 agent 协商对双方用户可见。
- 用户给自己 agent 的私有补充只对发送者和自己的 agent 可见。
- 对方用户和对方 agent 都不能收到私有原文。

在 `matched` 阶段：

- 房间表现为正常聊天室。
- 对方用户身份解除匿名。
- 消息默认公开。
- 现有 `@agent` 行为继续保留。

在 `closed` 阶段：

- 不允许继续发送新消息。
- 如果房间从未匹配成功，候选用户身份继续匿名。

## API 契约

扩展 `ChatRoomResponse`：

- `phase`：房间阶段。
- `a2a_candidate_rank`：可选候选排名。
- `a2a_result`：可选结果。
- `is_anonymous`：当前用户是否应看到匿名态。

扩展 `ChatRoomMemberResponse` 行为：

- 在 `a2a_negotiating` 阶段，当前用户可以看到自己和双方 agent，但对方 user 要匿名化。
- 在从未匹配成功的 `closed` 房间中，对方 user 继续匿名。
- 在 `matched` 阶段，返回真实成员资料。

扩展 `MessageResponse`：

- `visibility`：消息可见性。
- `recipient_user_id`：可选字段，仅在对当前用户安全且有必要时返回。

消息列表过滤必须感知当前用户：

- public 和 system 消息返回给双方用户。
- private 消息只返回给发送者。
- 永远不返回对方用户的 private-to-agent 消息。

## iOS UI 设计

聊天室列表可以按阶段分组或打标签：

- `AI 协商中`
- `已匹配聊天室`
- `已结束`

协商聊天室标题可以类似：

- `匿名搭子候选 1 · AI 协商中`
- `匿名搭子候选 2 · AI 协商中`
- `匿名搭子候选 3 · AI 协商中`

协商聊天室详情页顶部提示：

`AI 正在替双方确认是否适合搭。当前对方匿名，你可以补充信息，但只会告诉你的 AI。`

输入框 placeholder：

`补充给你的 AI，不会发给对方`

在 `a2a_negotiating` 阶段，禁用匿名对方用户的 profile 打开入口。agent 协商记录可以更突出，因为它是这个阶段的主要内容。

当房间阶段变成 `matched` 后，UI 应刷新房间并切换成正常聊天行为。

## Android 范围

第一版先按 iOS-first 实现，除非明确重新打开 Android 范围。后端 API 应对 Android 老客户端保持安全默认值，但 Android UI parity 不纳入第一版。

## 第一版不做

- 不做用户在三个候选中主动选择。
- 不做三个候选房间之间共享用户补充。
- 不要求长时间实时 agent 打字动画。
- 不做 A2A 失败房间的自动重新打开。
- 不做独立于聊天室之外的新 A2A Session 产品入口。

## 测试策略

后端测试覆盖：

- Top3 候选最多创建 3 个协商聊天室。
- private-to-agent 消息只对发送者可见。
- private-to-agent 消息只影响对应房间的 A2A 上下文。
- A2A 成功时只把一个房间提升为 `matched`。
- 其他涉及已匹配 event 的房间会被关闭。
- 匿名成员数据在匹配前隐藏，匹配后展示。
- 老客户端在新字段存在时仍能兼容合理默认值。

客户端或静态测试覆盖：

- iOS model 能解码新的 room 字段。
- 协商聊天室文案和输入框 placeholder 正确。
- 匹配前匿名 profile 行为正确。
- 匹配后恢复正常输入行为。

## 待实现阶段决定的问题

实现计划中需要决定具体数据库迁移方式，以及 A2A 消息是逐轮增量推送给用户，还是每轮结束后追加到房间。产品契约允许两种方式，但 UI 上仍应表现为一个可观看的协商阶段。
