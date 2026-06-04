import Foundation

/// WebSocket 实时消息服务，替代 30 秒轮询
final class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var pingTimer: Timer?
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
        guard let token = UserDefaults.standard.string(forKey: "dazi_access_token") else {
            print("[WS] No token, skip connect")
            return
        }

        isIntentionallyClosed = false

        let wsScheme = APIConfig.baseURL.hasPrefix("https") ? "wss" : "ws"
        let host = APIConfig.baseURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        guard let url = URL(string: "\(wsScheme)://\(host)/ws?token=\(token)") else {
            print("[WS] Invalid URL")
            return
        }

        disconnect()
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        startListening()
        startPing()
        reconnectDelay = 1
        print("[WS] Connecting to \(url.host ?? "")")
    }

    func disconnect() {
        isIntentionallyClosed = true
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Receive

    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
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
                // 继续监听
                self.startListening()
            case .failure(let error):
                print("[WS] Receive error: \(error.localizedDescription)")
                self.handleDisconnect()
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
        let pingMsg = URLSessionWebSocketTask.Message.string("{\"type\":\"ping\"}")
        webSocketTask?.send(pingMsg) { error in
            if let error {
                print("[WS] Ping error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask = nil

        guard !isIntentionallyClosed else { return }

        // 指数退避重连，最大 30 秒
        let delay = min(reconnectDelay, 30)
        print("[WS] Reconnecting in \(delay)s...")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.isIntentionallyClosed else { return }
            self.reconnectDelay *= 2
            self.connect()
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[WS] Connected")
        reconnectDelay = 1
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[WS] Closed: \(closeCode)")
        handleDisconnect()
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
