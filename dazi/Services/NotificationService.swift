import Foundation
import UIKit
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let remoteTokenKey = "dazi_apns_device_token"

    private override init() {
        super.init()
        center.delegate = self
    }

    func configure() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.registerForRemoteNotifications()
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        print("[Notification] Authorization error: \(error.localizedDescription)")
                    } else {
                        print("[Notification] Authorization granted: \(granted)")
                    }
                    guard granted else { return }
                    self.registerForRemoteNotifications()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    func handleRemoteDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: remoteTokenKey)
        registerStoredRemoteDeviceTokenIfAvailable()
    }

    func handleRemoteRegistrationError(_ error: Error) {
        print("[Notification] Remote registration error: \(error.localizedDescription)")
    }

    func registerStoredRemoteDeviceTokenIfAvailable() {
        guard let token = UserDefaults.standard.string(forKey: remoteTokenKey),
              APIClient.shared.isLoggedIn else {
            return
        }
        Task {
            do {
                try await APIClient.shared.registerPushDeviceToken(
                    token: token,
                    environment: Self.apnsEnvironment
                )
                print("[Notification] Remote device token registered")
            } catch {
                print("[Notification] Register remote token error: \(error.localizedDescription)")
            }
        }
    }

    func unregisterStoredRemoteDeviceTokenBeforeLogout() {
        guard let token = UserDefaults.standard.string(forKey: remoteTokenKey) else { return }
        APIClient.shared.unregisterPushDeviceTokenBeforeClearingAuth(
            token: token,
            environment: Self.apnsEnvironment
        )
    }

    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    func notifyRoomCreated(roomTitle: String, roomId: String) {
        schedule(
            identifier: "room_created_\(roomId)",
            title: "匹配成功，聊天室已创建",
            body: "「\(roomTitle)」的搭子聊天室已开启，去打个招呼吧。",
            roomId: roomId,
            type: "room_created"
        )
    }

    func notifyNewMessage(
        roomTitle: String,
        senderName: String,
        content: String,
        roomId: String,
        messageId: String
    ) {
        let preview = Self.truncated(content.trimmingCharacters(in: .whitespacesAndNewlines), limit: 80)
        schedule(
            identifier: "message_\(messageId)",
            title: senderName.isEmpty ? roomTitle : "\(senderName) · \(roomTitle)",
            body: preview.isEmpty ? "有一条新消息" : preview,
            roomId: roomId,
            type: "new_message"
        )
    }

    func updateBadge(_ count: Int) {
        center.setBadgeCount(max(0, count)) { error in
            if let error {
                print("[Notification] Badge error: \(error.localizedDescription)")
            }
        }
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        roomId: String,
        type: String
    ) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.addRequest(identifier: identifier, title: title, body: body, roomId: roomId, type: type)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        print("[Notification] Authorization error: \(error.localizedDescription)")
                    }
                    guard granted else { return }
                    self.registerForRemoteNotifications()
                    self.addRequest(identifier: identifier, title: title, body: body, roomId: roomId, type: type)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func addRequest(
        identifier: String,
        title: String,
        body: String,
        roomId: String,
        type: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = roomId
        content.userInfo = [
            "type": type,
            "room_id": roomId,
        ]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                print("[Notification] Schedule error: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }
}
