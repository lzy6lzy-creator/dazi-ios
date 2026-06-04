import SwiftUI

struct LoginView: View {
    @Environment(DataStore.self) private var dataStore
    var onLoginComplete: (_ isNewUser: Bool) -> Void

    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case phone, code }

    private let api = APIClient.shared

    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Text("I搭不搭")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.primaryColor)

                    Text("找到最合适的搭子")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                // Phone input
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text("+86")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 44)

                        TextField("手机号", text: $phone)
                            .keyboardType(.phonePad)
                            .focused($focusedField, equals: .phone)
                            .font(.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    // Code input + send button
                    HStack(spacing: 12) {
                        TextField("验证码", text: $code)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .code)
                            .font(.body)

                        Button {
                            sendCode()
                        } label: {
                            Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(canSendCode ? AppTheme.primaryColor : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(canSendCode ? AppTheme.primaryColor.opacity(0.1) : Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .disabled(!canSendCode)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                }
                .padding(.horizontal, 32)

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                // Login button
                Button {
                    doLogin()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("登录")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(canLogin ? AppTheme.primaryColor : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
                .disabled(!canLogin || isLoading)
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Spacer()

                Text("未注册的手机号将自动创建账号")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private var canSendCode: Bool {
        phone.count == 11 && countdown == 0
    }

    private var canLogin: Bool {
        phone.count == 11 && code.count >= 4
    }

    private func sendCode() {
        guard canSendCode else { return }
        errorMessage = nil
        focusedField = .code

        Task {
            do {
                let _ = try await api.sendVerificationCode(phone: phone)
                codeSent = true
                startCountdown()
            } catch {
                errorMessage = "发送失败，请检查网络"
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        Task {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
        }
    }

    private func doLogin() {
        guard canLogin else { return }
        isLoading = true
        errorMessage = nil
        focusedField = nil

        Task {
            do {
                let result = try await api.login(phone: phone, code: code)
                await MainActor.run {
                    isLoading = false
                    onLoginComplete(result.isNewUser ?? true)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "登录失败，请检查验证码"
                }
            }
        }
    }
}
