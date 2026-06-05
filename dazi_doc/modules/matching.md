# 匹配系统设计

最后更新：2026-06-05

## 1. 核心思路

匹配对象是 Event，不是用户。用户画像、Memory、活动偏好和限制都服务于“两个活动意图是否适合一起完成”。

```text
Event -> 硬过滤 -> 向量召回 -> A2A 精排 -> 聊天室 / 被动邀请
```

## 2. 主动匹配流程

```text
事件创建或更新
  -> 生成 event.embedding
  -> 源事件加锁
  -> 状态/时间/地点/黑名单硬过滤
  -> pgvector 召回 Top30
  -> 后过滤和阈值检查
  -> 第一轮 Top3 A2A
  -> 无通过则第二轮 next Top3 A2A
  -> 创建聊天室或回到 pending
```

创建聊天室前会重新锁定候选事件，避免候选已经被另一组匹配占用。

## 3. 硬过滤

硬过滤优先于相似度和 LLM 判断：

- 源事件必须是 `pending`。
- 源事件未过期，开始时间未到。
- 候选事件必须是 `pending`，不是同一事件，也不是同一用户。
- 候选事件必须有 embedding。
- 双方不能命中事件对或用户对黑名单。
- 双方时间范围完整时必须有交集。
- 地点相容性根据活动类型严格度判断。
- 向量相似度低于阈值的候选不进入 A2A。

## 4. A2A 精排

A2A 负责判断“看起来相似”的候选是否真的适合。

输出字段：

- `compatibility`：0 到 1 的匹配度。
- `summary`：匹配摘要。
- `match_reasons`：适合原因。
- `potential_issues`：潜在风险。
- `dialogue`：双方 AI 代表活动意图进行的简短协商记录。

只有 `compatibility` 达到阈值才允许创建聊天室或形成候选邀请。

## 5. 被动邀请

主动匹配多轮失败后，事件可以进入被动邀请逻辑。被动邀请不直接建房，而是向目标用户展示一个待确认请求。

触发条件：

- 事件仍是 `pending`。
- `match_round` 达到被动阈值。
- 事件有 embedding。
- 事件未过期、未开始。

目标用户接受后创建聊天室；拒绝后写入黑名单，避免同一对用户反复被推送。

## 6. 聊天室投票与黑名单

聊天室中双方可以投“搭 / 不搭”。任一方选择“不搭”后，应关闭或停止推进该匹配，并写入屏蔽关系。

黑名单分两类：

- 事件对：同一对事件不再重复匹配。
- 用户对：同一对用户后续也不再被主动或被动撮合。

## 7. 可观测性

匹配日志需要回答：

- 源事件为什么进入或未进入匹配。
- 每个候选在哪一步被过滤。
- A2A 的 compatibility、理由和风险。
- 被动邀请创建、接受、拒绝的状态变化。

相关管理端入口在 `GET /api/admin/match-logs`、匹配预览和测试数据接口。

## 8. 相关代码

- `dazi-server/app/services/matching_service.py`
- `dazi-server/app/services/a2a_matcher.py`
- `dazi-server/app/services/passive_matching_service.py`
- `dazi-server/app/services/match_blocklist_service.py`
- `dazi-server/app/services/matching_policy.py`
- `dazi-server/app/api/events.py`
- `dazi-server/app/api/chat.py`
- `dazi-server/app/api/admin.py`

