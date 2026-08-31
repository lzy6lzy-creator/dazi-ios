import SwiftUI
import UIKit

@main
struct daziApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var dataStore: DataStore

    init() {
        #if DEBUG
        let store = DataStore(restoringSession: !RuntimeTesting.isTesting)
        if RuntimeTesting.isUITesting {
            RuntimeTesting.seedActivities(in: store)
        }
        _dataStore = State(initialValue: store)
        if RuntimeTesting.isTesting { return }
        #else
        _dataStore = State(initialValue: DataStore())
        #endif
        NotificationService.shared.configure()
        preWarmKeyboard()
    }

    /// App state: login → onboarding (new user) → main
    enum AppState {
        case login
        case onboarding
        case main
    }

    @State private var appState: AppState = .login

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if RuntimeTesting.isUITesting {
                EventListView().environment(dataStore)
            } else if RuntimeTesting.isTesting {
                Color.clear
            } else {
                applicationRoot
            }
            #else
            applicationRoot
            #endif
        }
    }

    private var applicationRoot: some View {
            ZStack {
                switch appState {
                case .login:
                    LoginView { isNewUser in
                        withAnimation(.spring(duration: 0.5)) {
                            if isNewUser {
                                appState = .onboarding
                            } else {
                                // 老用户：从服务器拉取 profile 后进入主界面
                                dataStore.loginAsReturningUser()
                                appState = .main
                            }
                        }
                    }

                case .onboarding:
                    OnboardingView {
                        withAnimation(.spring(duration: 0.5)) {
                            appState = .main
                        }
                    }

                case .main:
                    MainTabView()
                        .onAppear {
                            dataStore.locationManager.requestPermission()
                        }
                }

                // Global toast overlay
                ToastContainerView()
            }
            .environment(dataStore)
            .onAppear {
                // 判断初始状态
                if dataStore.isRegistered {
                    appState = .main
                } else if APIClient.shared.isLoggedIn {
                    // 已登录但未完善资料（中途退出 onboarding 的情况）
                    appState = .onboarding
                } else {
                    appState = .login
                }
            }
            .onChange(of: dataStore.isRegistered) { _, newValue in
                if !newValue {
                    // logout 触发
                    appState = .login
                }
            }
            .onOpenURL { url in
                captureInvitationCode(from: url)
            }
    }

    private func captureInvitationCode(from url: URL) {
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2, components[0].lowercased() == "i" else { return }
        let code = components[1]
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard code.count == 8 else { return }
        UserDefaults.standard.set(code, forKey: "pendingInvitationCode")
    }

    /// Force iOS to load the keyboard subsystem at launch so the first tap is instant.
    private func preWarmKeyboard() {
        let tempField = UITextField()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            tempField.alpha = 0
            window.addSubview(tempField)
            tempField.becomeFirstResponder()
            tempField.resignFirstResponder()
            tempField.removeFromSuperview()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                tempField.alpha = 0
                window.addSubview(tempField)
                tempField.becomeFirstResponder()
                tempField.resignFirstResponder()
                tempField.removeFromSuperview()
            }
        }
    }
}
