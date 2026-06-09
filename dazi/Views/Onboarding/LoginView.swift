import SwiftUI

struct LoginView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onLoginComplete: (_ isNewUser: Bool) -> Void

    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didAppear = false
    @FocusState private var focusedField: Field?

    private enum Field { case phone, code }

    private let api = APIClient.shared
    private let internalTestCode = "121212"

    var body: some View {
        ZStack {
            LoginPalette.background.ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    brandSection
                        .padding(.top, topBrandPadding(for: proxy.size.height))
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear || reduceMotion ? 0 : 12)

                    Spacer(minLength: 40)

                    VStack(spacing: 14) {
                        loginCard

                        Text("未注册手机号将自动创建账号")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(LoginPalette.tertiaryText)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 34))
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear || reduceMotion ? 0 : 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            guard !didAppear else { return }
            if reduceMotion {
                didAppear = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    didAppear = true
                }
            }
        }
    }

    private var brandSection: some View {
        ZStack(alignment: .leading) {
            MatchingMotif()
                .frame(width: 245, height: 88)
                .offset(x: 76, y: -24)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("i")
                        .foregroundStyle(LoginPalette.accent)
                    Text("搭不搭")
                        .foregroundStyle(LoginPalette.primaryText)
                }
                .font(.system(size: 36, weight: .semibold, design: .default))

                Text("找到合适的活动搭子")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(LoginPalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 40)
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            phoneField
            codeField

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button {
                doLogin()
            } label: {
                ZStack {
                    Text("进入")
                        .font(.system(size: 17, weight: .semibold))
                        .opacity(isLoading ? 0 : 1)

                    ProgressView()
                        .tint(.white)
                        .opacity(isLoading ? 1 : 0)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .background(canLogin ? LoginPalette.accent : LoginPalette.disabledButton)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .disabled(!canLogin || isLoading)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: canLogin)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isLoading)
        }
        .padding(22)
        .background(.white.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(LoginPalette.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 26, x: 0, y: 16)
    }

    private var phoneField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("+86")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LoginPalette.primaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LoginPalette.primaryText)
            }

            Rectangle()
                .fill(LoginPalette.divider)
                .frame(width: 1, height: 26)

            TextField("手机号", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($focusedField, equals: .phone)
                .font(.system(size: 17))
                .foregroundStyle(LoginPalette.primaryText)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(fieldBackground(isFocused: focusedField == .phone))
        .overlay(fieldStroke(isFocused: focusedField == .phone))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: focusedField)
    }

    private var codeField: some View {
        HStack(spacing: 12) {
            TextField("验证码", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .font(.system(size: 17))
                .foregroundStyle(LoginPalette.primaryText)

            Rectangle()
                .fill(LoginPalette.divider)
                .frame(width: 1, height: 26)

            Button {
                sendCode()
            } label: {
                Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSendCode ? LoginPalette.accent : LoginPalette.tertiaryText)
                    .frame(width: 88, height: 34)
                    .background(
                        Capsule()
                            .fill(canSendCode ? LoginPalette.accentSoft : Color.clear)
                    )
            }
            .disabled(!canSendCode)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(fieldBackground(isFocused: focusedField == .code))
        .overlay(fieldStroke(isFocused: focusedField == .code))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: focusedField)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: canSendCode)
    }

    private var canSendCode: Bool {
        phone.count == 11 && countdown == 0
    }

    private var canLogin: Bool {
        phone.count == 11 && code.count >= 4
    }

    private func topBrandPadding(for height: CGFloat) -> CGFloat {
        min(max(height * 0.23, 150), 210)
    }

    private func fieldBackground(isFocused: Bool) -> some ShapeStyle {
        isFocused ? LoginPalette.focusedFieldBackground : LoginPalette.fieldBackground
    }

    private func fieldStroke(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isFocused ? LoginPalette.focusStroke : Color.clear, lineWidth: 1)
    }

    private func sendCode() {
        guard canSendCode else { return }
        errorMessage = nil
        focusedField = .code

        Task {
            do {
                let _ = try await api.sendVerificationCode(phone: phone)
                await MainActor.run {
                    code = internalTestCode
                    codeSent = true
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    errorMessage = messageForSendCodeError(error)
                }
            }
        }
    }

    private func messageForSendCodeError(_ error: Error) -> String {
        if case APIError.serverError(let statusCode, let body) = error, statusCode == 403 {
            if body.contains("未加入内部测试白名单") {
                return "该手机号未加入内部测试白名单，请先联系管理员开通内测资格"
            }
            return "该手机号暂未加入内部测试白名单"
        }
        return "发送失败，请检查网络"
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

private enum LoginPalette {
    static let background = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let primaryText = Color(red: 0.11, green: 0.14, blue: 0.18)
    static let secondaryText = Color(red: 0.43, green: 0.46, blue: 0.50)
    static let tertiaryText = Color(red: 0.62, green: 0.64, blue: 0.67)
    static let accent = Color(red: 0.91, green: 0.34, blue: 0.23)
    static let accentSoft = Color(red: 1.0, green: 0.93, blue: 0.90)
    static let fieldBackground = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let focusedFieldBackground = Color(red: 1.0, green: 0.985, blue: 0.97)
    static let divider = Color.black.opacity(0.10)
    static let cardStroke = Color.black.opacity(0.06)
    static let focusStroke = Color(red: 0.91, green: 0.34, blue: 0.23).opacity(0.35)
    static let disabledButton = Color(red: 0.80, green: 0.79, blue: 0.77)
}

private struct MatchingMotif: View {
    var body: some View {
        Canvas { context, size in
            let first = Path { path in
                path.move(to: CGPoint(x: 8, y: size.height * 0.68))
                path.addQuadCurve(
                    to: CGPoint(x: size.width * 0.88, y: size.height * 0.56),
                    control: CGPoint(x: size.width * 0.44, y: size.height * 0.08)
                )
            }
            let second = Path { path in
                path.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.58))
                path.addQuadCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.86),
                    control: CGPoint(x: size.width * 0.72, y: size.height * 0.48)
                )
            }

            context.stroke(first, with: .color(LoginPalette.accent.opacity(0.12)), lineWidth: 1)
            context.stroke(second, with: .color(Color.black.opacity(0.06)), lineWidth: 1)

            context.fill(
                Path(ellipseIn: CGRect(x: size.width * 0.60, y: size.height * 0.18, width: 8, height: 8)),
                with: .color(LoginPalette.accent.opacity(0.85))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: size.width * 0.86, y: size.height * 0.50, width: 8, height: 8)),
                with: .color(Color.black.opacity(0.16))
            )
        }
        .allowsHitTesting(false)
    }
}
