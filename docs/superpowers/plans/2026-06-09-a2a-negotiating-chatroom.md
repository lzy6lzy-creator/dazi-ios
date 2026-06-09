# A2A 协商聊天室 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Top3 A2A 候选在匹配完成前以匿名协商聊天室形式展示，用户可旁观并私下补充给自己的 agent，成功后转为普通聊天室。

**Architecture:** 复用现有 `ChatRoom`，新增 phase/result/rank 字段和消息 visibility 字段。后端负责匿名成员响应、私有消息过滤、A2A 房间创建、成功提升和其余候选关闭；iOS 根据 phase 切换列表分组、标题、顶部提示、输入框语义和匿名 profile 行为。

**Tech Stack:** FastAPI, SQLAlchemy async, PostgreSQL runtime schema guards, SwiftUI, iOS Codable models, static Python regression tests.

---

### Task 1: 后端模型和 API 合同

**Files:**
- Modify: `app/models/chat.py`
- Modify: `app/api/schemas.py`
- Modify: `app/main.py`
- Modify: `app/api/chat.py`
- Test: `tests/test_a2a_negotiating_chatroom_static.py`

- [ ] Add `ChatRoom.phase`, `ChatRoom.a2a_candidate_rank`, `ChatRoom.a2a_result`, `ChatMessage.visibility`, and `ChatMessage.recipient_user_id` with safe defaults.
- [ ] Add matching runtime schema guards in `_ensure_runtime_schema`.
- [ ] Extend `ChatRoomResponse` and `MessageResponse` with phase/visibility fields.
- [ ] Make room list responses anonymize the other user while phase is `a2a_negotiating` or closed before match.
- [ ] Filter private messages in room message history.

### Task 2: A2A matching lifecycle

**Files:**
- Modify: `app/services/a2a_matcher.py`
- Modify: `app/services/matching_service.py`
- Test: `tests/test_a2a_negotiating_chatroom_static.py`

- [ ] Allow `A2AMatcher.evaluate(...)` to accept room-scoped private user additions and an optional public-message callback.
- [ ] Create up to three `a2a_negotiating` rooms before evaluating the Top3 A2A window.
- [ ] Store public agent turns as room messages.
- [ ] On winner commit, promote exactly the winning room to `matched`.
- [ ] Close other negotiating rooms involving either matched event as `lost_to_other_candidate`.

### Task 3: iOS room model and UI behavior

**Files:**
- Modify: `dazi/Services/APIClient.swift`
- Modify: `dazi/Models/ChatRoom.swift`
- Modify: `dazi/Models/Message.swift`
- Modify: `dazi/Services/DataStore.swift`
- Modify: `dazi/Views/ChatRoom/ChatRoomListView.swift`
- Modify: `dazi/Views/ChatRoom/ChatRoomDetailView.swift`

- [ ] Decode new room and message fields with defaults for old responses.
- [ ] Add `ChatRoom.phase`, `isNegotiating`, and `isMatchedRoom` helpers.
- [ ] Use private-to-agent placeholder and optimistic message copy during `a2a_negotiating`.
- [ ] Split room list into `AI 协商中`, `已匹配聊天室`, and `已结束`.
- [ ] Hide vote/profile actions during negotiation and show negotiation phase banner.

### Task 4: Static regression coverage

**Files:**
- Create: `tests/test_a2a_negotiating_chatroom_static.py`

- [ ] Assert schema/model additions exist.
- [ ] Assert private visibility filtering exists.
- [ ] Assert matching creates negotiating rooms and promotes only the winner.
- [ ] Assert iOS files decode and display negotiating phase copy.

### Validation note

This plan intentionally does not run tests, builds, or git commands unless the user explicitly asks for validation. The test files are added as regression coverage but not executed in this pass.
