import SwiftUI

struct ChatRoomDetailView: View {
    @Environment(DataStore.self) private var dataStore
    let roomId: String
    @State private var inputText = ""
    @State private var showMembers = false
    @State private var showPartnerProfile = false
    @State private var showAgentDialogue = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var voteStatus: VoteStatus?
    @State private var isVoting = false
    @FocusState private var isInputFocused: Bool

    private var room: ChatRoom? {
        dataStore.chatRooms.first(where: { $0.id == roomId })
    }

    /// 除自己以外的其他参与者，用于 @ 候选
    private var mentionCandidates: [User] {
        guard let room else { return [] }
        return room.participants.filter { $0.id != dataStore.currentUser.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let room {
                messageList(room: room)

                if room.isActive {
                    ChatInputBar(
                        text: $inputText,
                        isInputFocused: $isInputFocused,
                        placeholder: "输入消息... @ 可呼叫其他人",
                        mentionCandidates: mentionCandidates
                    ) {
                        sendMessage()
                    }
                } else {
                    closedBanner
                }
            }
        }
        .background(AppTheme.backgroundColor)
        .onTapGesture {
            isInputFocused = false
        }
        .navigationTitle(room?.displayTitle ?? "聊天室")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if let partner = room?.participants.first(where: { !$0.isAgent && $0.id != dataStore.currentUser.id }) {
                        Button { showPartnerProfile = true } label: {
                            AvatarView(
                                imageData: partner.avatarImageData,
                                emoji: partner.avatarEmoji,
                                size: 28,
                                backgroundColor: AppTheme.primaryColor.opacity(0.1)
                            )
                        }
                    }

                    Button {
                        showMembers = true
                    } label: {
                        Image(systemName: "person.3.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
        .sheet(isPresented: $showPartnerProfile) {
            if let partner = room?.participants.first(where: { !$0.isAgent && $0.id != dataStore.currentUser.id }) {
                PartnerProfileView(partner: partner)
            }
        }
        .sheet(isPresented: $showMembers) {
            if let room {
                ChatRoomMembersView(room: room)
                    .presentationDetents([.medium])
            }
        }
        .onAppear {
            dataStore.markRoomAsRead(roomId)
            dataStore.pendingChatRoomId = roomId
            // 加载历史消息
            if room?.messages.isEmpty == true {
                Task {
                    await dataStore.fetchRoomMessages(roomId: roomId)
                }
            }
            // 加载投票状态
            Task {
                await loadVoteStatus()
            }
            // 消息轮询 fallback（WebSocket 不稳定时保证消息可达）
            pollingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { break }
                    await dataStore.fetchRoomMessages(roomId: roomId)
                }
            }
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
            if dataStore.pendingChatRoomId == roomId {
                dataStore.pendingChatRoomId = nil
            }
        }
    }

    private func messageList(room: ChatRoom) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    matchSummaryHeader(room: room)

                    // 投票区域
                    if room.isActive {
                        voteSection
                    }

                    // Agent 对话历史（可展开）
                    if !room.agentDialogueLog.isEmpty {
                        agentDialogueCard(room: room)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(Array(room.messages.enumerated()), id: \.element.id) { index, message in
                            if index == 0 || !Calendar.current.isDate(message.timestamp, inSameDayAs: room.messages[index - 1].timestamp) {
                                DateSeparator(date: message.timestamp)
                            }
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: room.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastId = room.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func matchSummaryHeader(room: ChatRoom) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: -8) {
                ForEach(room.participants.filter { !$0.isAgent }) { user in
                    AvatarView(
                        imageData: user.avatarImageData,
                        emoji: user.avatarEmoji,
                        size: 44,
                        backgroundColor: AppTheme.primaryColor.opacity(0.1)
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }

            Text("匹配成功")
                .font(.headline)

            Text(room.matchSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Agent 对话历史卡片

    private func agentDialogueCard(room: ChatRoom) -> some View {
        let myAgent = room.participants.first(where: { $0.isAgent && $0.id.hasPrefix("agent_\(dataStore.currentUser.id)") })
            ?? room.participants.first(where: { $0.isAgent && !$0.id.contains("partner") })
        let partnerAgent = room.participants.first(where: { $0.isAgent && $0.id.contains("partner") })
            ?? room.participants.filter(\.isAgent).last

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAgentDialogue.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // 两个 Agent 头像叠加
                    ZStack {
                        if let a1 = myAgent {
                            AvatarView(
                                imageData: a1.avatarImageData,
                                emoji: a1.avatarEmoji,
                                size: 28,
                                backgroundColor: AppTheme.agentColor.opacity(0.12)
                            )
                            .offset(x: -8)
                        }
                        if let a2 = partnerAgent {
                            AvatarView(
                                imageData: a2.avatarImageData,
                                emoji: a2.avatarEmoji,
                                size: 28,
                                backgroundColor: AppTheme.agentColor.opacity(0.12)
                            )
                            .offset(x: 8)
                        }
                    }
                    .frame(width: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("经纪人匹配对话")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("\(myAgent?.name ?? "Agent") 与 \(partnerAgent?.name ?? "Agent") 的沟通记录")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: showAgentDialogue ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(AppTheme.agentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
            }
            .buttonStyle(.plain)

            if showAgentDialogue {
                dialogueContent(room: room, myAgent: myAgent, partnerAgent: partnerAgent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
    }

    private func dialogueContent(room: ChatRoom, myAgent: User?, partnerAgent: User?) -> some View {
        let lines = parseDialogueLog(room.agentDialogueLog, myAgentName: myAgent?.name, partnerAgentName: partnerAgent?.name)

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    let agent = line.isMyAgent ? myAgent : partnerAgent
                    AvatarView(
                        imageData: agent?.avatarImageData,
                        emoji: agent?.avatarEmoji ?? "🤖",
                        size: 24,
                        backgroundColor: AppTheme.agentColor.opacity(0.1)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.speakerName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.agentColor)
                        Text(line.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
        .padding(.top, 4)
        .padding(.horizontal, 0)
    }

    // MARK: - Dialogue Log Parsing

    private struct DialogueLine {
        let speakerName: String
        let content: String
        let isMyAgent: Bool
    }

    private func parseDialogueLog(_ log: String, myAgentName: String?, partnerAgentName: String?) -> [DialogueLine] {
        let myName = myAgentName ?? "点点"
        let partnerName = partnerAgentName ?? "圆圆"

        // 尝试按换行分段，识别 "AgentA:" / "AgentB:" 或 "点点:" / "圆圆:" 格式
        let rawLines = log.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var result: [DialogueLine] = []
        var currentSpeaker = myName
        var currentIsMyAgent = true
        var currentContent = ""

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 检测说话者标识
            var foundSpeaker: (String, Bool)?
            for (name, isMine) in [(myName, true), (partnerName, false), ("AgentA", true), ("AgentB", false), ("经纪人A", true), ("经纪人B", false)] {
                if trimmed.hasPrefix("\(name):") || trimmed.hasPrefix("\(name)：") || trimmed.hasPrefix("**\(name)**:") || trimmed.hasPrefix("**\(name)**：") {
                    foundSpeaker = (name, isMine)
                    break
                }
            }

            if let (speaker, isMine) = foundSpeaker {
                // 保存之前的内容
                if !currentContent.isEmpty {
                    result.append(DialogueLine(speakerName: currentSpeaker, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), isMyAgent: currentIsMyAgent))
                }
                // 开始新的说话段
                currentSpeaker = speaker == "AgentA" || speaker == "经纪人A" ? myName : (speaker == "AgentB" || speaker == "经纪人B" ? partnerName : speaker)
                currentIsMyAgent = isMine
                // 提取冒号后的内容
                let separators = ["\(speaker):", "\(speaker)：", "**\(speaker)**:", "**\(speaker)**："]
                var content = trimmed
                for sep in separators {
                    if content.hasPrefix(sep) {
                        content = String(content.dropFirst(sep.count))
                        break
                    }
                }
                currentContent = content.trimmingCharacters(in: .whitespaces)
            } else {
                // 续接当前说话者
                if currentContent.isEmpty {
                    currentContent = trimmed
                } else {
                    currentContent += "\n" + trimmed
                }
            }
        }

        // 追加最后一段
        if !currentContent.isEmpty {
            result.append(DialogueLine(speakerName: currentSpeaker, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), isMyAgent: currentIsMyAgent))
        }

        // 如果解析失败（没有识别到任何发言人），整段作为对话内容展示
        if result.isEmpty && !log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(DialogueLine(speakerName: myName, content: log.trimmingCharacters(in: .whitespacesAndNewlines), isMyAgent: true))
        }

        return result
    }

    // MARK: - Vote

    @ViewBuilder
    private var voteSection: some View {
        if let status = voteStatus {
            if status.result == "matched" {
                voteBanner(text: "双方都选了「搭」！🎉", color: .green)
            } else if status.result == "rejected" {
                voteBanner(text: "有人选了「不搭」，聊天室即将关闭", color: .red)
            } else if status.myVote != nil {
                voteBanner(text: "你已投票，等待对方...", color: .orange)
            } else {
                voteButtons
            }
        } else {
            voteButtons
        }
    }

    private func voteBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var voteButtons: some View {
        HStack(spacing: 16) {
            Button {
                submitVote("da")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("搭")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.green)
                .clipShape(Capsule())
            }
            .disabled(isVoting)

            Button {
                submitVote("bu_da")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("不搭")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
            }
            .disabled(isVoting)
        }
        .padding(.vertical, 8)
    }

    private func submitVote(_ vote: String) {
        isVoting = true
        Task {
            do {
                try await APIClient.shared.submitRoomVote(roomId: roomId, vote: vote)
                await loadVoteStatus()
            } catch {
                await MainActor.run {
                    dataStore.showToast("投票失败，请重试", type: .error)
                }
            }
            await MainActor.run { isVoting = false }
        }
    }

    private func loadVoteStatus() async {
        do {
            let status = try await APIClient.shared.fetchVoteStatus(roomId: roomId)
            await MainActor.run {
                self.voteStatus = status
            }
        } catch {
            // 静默失败，投票状态非关键
        }
    }

    // MARK: - Other

    private var closedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("活动已结束，聊天室已关闭")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        dataStore.sendMessageInRoom(roomId, text: text)
    }
}

// MARK: - Members View

struct ChatRoomMembersView: View {
    let room: ChatRoom

    var body: some View {
        NavigationStack {
            List {
                Section("参与者") {
                    ForEach(room.participants) { member in
                        HStack(spacing: 12) {
                            AvatarView(
                                imageData: member.avatarImageData,
                                emoji: member.avatarEmoji,
                                size: 44,
                                backgroundColor: member.isAgent ? AppTheme.agentColor.opacity(0.12) : AppTheme.primaryColor.opacity(0.08)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    if member.isAgent {
                                        Text("AI")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.agentColor)
                                            .clipShape(Capsule())
                                    }
                                }

                                if !member.bio.isEmpty {
                                    Text(member.bio)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Agent 只能看到自己用户的偏好记忆，无法查看其他人的信息")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("聊天室成员")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
