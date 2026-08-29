import Foundation

/// WebSocket 实时消息服务，替代 30 秒轮询
final class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectDelay: TimeInterval = 1
    private var isIntentionallyClosed = false

    /// 收到新聊天室消息时的回调
    var onNewMessage: ((_ roomId: String, _ message: WSMessagePayload) -> Void)?
    /// 收到事件状态更新时的回调
    var onEventUpdate: ((_ eventId: String, _ status: String) -> Void)?
    /// 收到新聊天室创建通知
    var onRoomCreated: ((_ roomData: [String: Any]) -> Void)?
    /// 收到被动匹配邀请
    var onMatchRequestCreated: ((_ requestId: String) -> Void)?
    /// 收到记忆更新
    var onMemoryUpdated: ((_ action: String, _ memory: APIMemoryResponse) -> Void)?

    private override init() {
        super.init()
        session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue()
        )
    }

    // MARK: - Connect / Disconnect

    func connect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        guard let token = APIClient.shared.currentAccessToken else {
            print("[WS] No token, skip connect")
            return
        }

        let wsScheme = APIConfig.baseURL.hasPrefix("https") ? "wss" : "ws"
        let host = APIConfig.baseURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        guard let url = URL(string: "\(wsScheme)://\(host)/ws") else {
            print("[WS] Invalid URL")
            return
        }

        disconnect()
        isIntentionallyClosed = false

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()
        startListening(task)
        startPing()
        print("[WS] Connecting to \(url.host ?? "")")
    }

    func disconnect() {
        isIntentionallyClosed = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Receive

    private func startListening(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            guard self.webSocketTask === task else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.startListening(task)
            case .failure(let error):
                print("[WS] Receive error: \(error.localizedDescription)")
                self.handleDisconnect(task)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "pong":
            break
        case "new_message":
            if let roomId = json["room_id"] as? String,
               let msgDict = json["message"] as? [String: Any] {
                let payload = WSMessagePayload(
                    id: msgDict["id"] as? String ?? UUID().uuidString,
                    roomId: roomId,
                    senderId: msgDict["sender_id"] as? String ?? "",
                    senderType: msgDict["sender_type"] as? String ?? "user",
                    content: msgDict["content"] as? String ?? "",
                    mentions: msgDict["mentions"] as? [String],
                    createdAt: msgDict["created_at"] as? String
                )
                DispatchQueue.main.async {
                    self.onNewMessage?(roomId, payload)
                }
            }
        case "event_update":
            if let eventId = json["event_id"] as? String,
               let status = json["status"] as? String {
                DispatchQueue.main.async {
                    self.onEventUpdate?(eventId, status)
                }
            }
        case "room_created":
            if let roomData = json["room"] as? [String: Any] {
                DispatchQueue.main.async {
                    self.onRoomCreated?(roomData)
                }
            } else if let roomId = json["room_id"] as? String {
                DispatchQueue.main.async {
                    self.onRoomCreated?(["id": roomId])
                }
            }
        case "match_request_created":
            if let requestId = json["request_id"] as? String {
                DispatchQueue.main.async {
                    self.onMatchRequestCreated?(requestId)
                }
            }
        case "memory_updated":
            if let action = json["action"] as? String,
               let memoryDict = json["memory"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: memoryDict) {
                Task { @MainActor in
                    if let memory = try? JSONDecoder().decode(APIMemoryResponse.self, from: data) {
                        self.onMemoryUpdated?(action, memory)
                    }
                }
            }
        default:
            print("[WS] Unknown message type: \(type)")
        }
    }

    // MARK: - Ping / Pong

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard let task = webSocketTask else { return }
        let pingMsg = URLSessionWebSocketTask.Message.string("{\"type\":\"ping\"}")
        task.send(pingMsg) { [weak self] error in
            if let error {
                print("[WS] Ping error: \(error.localizedDescription)")
                self?.handleDisconnect(task)
            }
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect(_ task: URLSessionWebSocketTask) {
        guard webSocketTask === task else { return }
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask = nil

        guard !isIntentionallyClosed else { return }

        // 指数退避重连，最大 30 秒
        let delay = min(reconnectDelay, 30)
        print("[WS] Reconnecting in \(delay)s...")
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isIntentionallyClosed else { return }
            self.reconnectDelay *= 2
            self.connect()
        }
        reconnectWorkItem?.cancel()
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard self.webSocketTask === webSocketTask else { return }
        print("[WS] Connected")
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectDelay = 1
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard self.webSocketTask === webSocketTask else { return }
        print("[WS] Closed: \(closeCode)")
        handleDisconnect(webSocketTask)
    }
}

// MARK: - WebSocket Message Payload

struct WSMessagePayload {
    let id: String
    let roomId: String
    let senderId: String
    let senderType: String
    let content: String
    let mentions: [String]?
    let createdAt: String?
}
