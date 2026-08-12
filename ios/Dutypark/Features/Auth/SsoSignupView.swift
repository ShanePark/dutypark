import SwiftUI

nonisolated enum SsoSignupCancellationDecision: Equatable {
    case dismiss
    case confirmDiscard
    case blocked
}

nonisolated struct SsoSignupPresentationPolicy {
    static func hasDraft(
        username: String,
        agreesToTerms: Bool,
        agreesToPrivacy: Bool
    ) -> Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            agreesToTerms || agreesToPrivacy
    }

    static func cancellationDecision(
        username: String,
        agreesToTerms: Bool,
        agreesToPrivacy: Bool,
        isWorking: Bool
    ) -> SsoSignupCancellationDecision {
        if isWorking {
            return .blocked
        }
        return hasDraft(
            username: username,
            agreesToTerms: agreesToTerms,
            agreesToPrivacy: agreesToPrivacy
        ) ? .confirmDiscard : .dismiss
    }
}

struct SsoSignupView: View {
    let uuid: String
    let oauthClient: MobileOAuthClient

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var agreesToTerms = false
    @State private var agreesToPrivacy = false
    @State private var policies: CurrentPoliciesDTO?
    @State private var isWorking = false
    @State private var errorKey: String?
    @State private var displayedPolicy: PolicyDTO?
    @State private var showsDiscardConfirmation = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 8) {
                            Text(oauthString("auth.oauth.signup.title"))
                                .font(DPFont.bold(size: 30, relativeTo: .largeTitle))
                                .foregroundStyle(DPColor.textPrimary)
                            Text(oauthString("auth.oauth.signup.subtitle"))
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)

                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(oauthString("auth.oauth.signup.name"))
                                    Spacer()
                                    Text("\(username.count)/10")
                                        .foregroundStyle(DPColor.textMuted)
                                }
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textSecondary)

                                TextField(
                                    oauthString("auth.oauth.signup.name.placeholder"),
                                    text: $username
                                )
                                .font(DPTypography.body)
                                .textContentType(.name)
                                .focused($isNameFocused)
                                .dpInputChrome(isFocused: isNameFocused, isDisabled: isWorking)
                                .disabled(isWorking)
                                .onChange(of: username) { _, value in
                                    if value.count > 10 {
                                        username = String(value.prefix(10))
                                    }
                                }

                                Text(oauthString("auth.oauth.signup.name.help"))
                                    .font(DPTypography.supporting)
                                    .foregroundStyle(DPColor.textMuted)
                            }

                            if let terms = policies?.terms, let privacy = policies?.privacy {
                                policySection(
                                    title: oauthString("auth.oauth.signup.terms"),
                                    policy: terms,
                                    isAgreed: $agreesToTerms
                                )
                                policySection(
                                    title: oauthString("auth.oauth.signup.privacy"),
                                    policy: privacy,
                                    isAgreed: $agreesToPrivacy
                                )
                            } else if errorKey == nil {
                                ProgressView()
                                    .tint(DPColor.accent)
                                    .frame(maxWidth: .infinity, minHeight: 160)
                            }

                            if let errorKey {
                                Text(oauthString(errorKey))
                                    .font(DPTypography.supporting)
                                    .foregroundStyle(DPColor.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(DPColor.dangerSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: DPRadius.large)
                                            .stroke(DPColor.dangerBorder)
                                    }
                                    .accessibilityIdentifier("oauth.signup.error")
                            }

                            Button(action: submit) {
                                Group {
                                    if isWorking {
                                        ProgressView().tint(DPColor.textOnDark)
                                    } else {
                                        Text(oauthString("auth.oauth.signup.submit"))
                                    }
                                }
                                .font(DPFont.bold(size: 16, relativeTo: .headline))
                                .foregroundStyle(DPColor.textOnDark)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(DPColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.5)
                            .accessibilityIdentifier("oauth.signup.submit")
                        }
                        .padding(20)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)

                        if let terms = policies?.terms, let privacy = policies?.privacy {
                            HStack(spacing: 8) {
                                Button(oauthString("auth.oauth.signup.terms")) {
                                    displayedPolicy = terms
                                }
                                Text("|")
                                Button(oauthString("auth.oauth.signup.privacy")) {
                                    displayedPolicy = privacy
                                }
                            }
                            .buttonStyle(.plain)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .frame(minHeight: DPSize.minimumTouchTarget)
                        }
                    }
                    .frame(maxWidth: 576)
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(DPColor.backgroundSecondary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(oauthString("auth.oauth.cancel"), action: requestCancellation)
                        .font(DPTypography.label)
                        .frame(
                            minWidth: DPSize.minimumTouchTarget,
                            minHeight: DPSize.minimumTouchTarget
                        )
                        .disabled(isWorking)
                        .accessibilityIdentifier("oauth.signup.cancel")
                }
            }
            .task { await loadPolicies() }
        }
        .interactiveDismissDisabled(preventsInteractiveDismissal)
        .alert(
            oauthString("auth.oauth.signup.discard.title"),
            isPresented: $showsDiscardConfirmation
        ) {
            Button(oauthString("auth.oauth.signup.discard.action"), role: .destructive) {
                dismiss()
            }
            Button(oauthString("auth.oauth.signup.discard.continue"), role: .cancel) {}
        } message: {
            Text(oauthString("auth.oauth.signup.discard.message"))
        }
        .sheet(
            isPresented: Binding(
                get: { displayedPolicy != nil },
                set: { if !$0 { displayedPolicy = nil } }
            )
        ) {
            if let displayedPolicy {
                NavigationStack {
                    ScrollView {
                        policyText(displayedPolicy.content)
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DPSpacing.medium)
                            .textSelection(.enabled)
                    }
                    .background(DPColor.backgroundSecondary)
                    .navigationTitle(policyTitle(for: displayedPolicy))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(oauthString("auth.oauth.close")) {
                                self.displayedPolicy = nil
                            }
                            .frame(
                                minWidth: DPSize.minimumTouchTarget,
                                minHeight: DPSize.minimumTouchTarget
                            )
                            .accessibilityIdentifier("oauth.signup.policy.close")
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .accessibilityIdentifier("screen.oauth.signup.policy")
            }
        }
        .accessibilityIdentifier("screen.oauth.signup")
    }

    private var canSubmit: Bool {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isWorking && !name.isEmpty && name.count <= 10 && agreesToTerms && agreesToPrivacy &&
            policies?.terms != nil && policies?.privacy != nil
    }

    private var cancellationDecision: SsoSignupCancellationDecision {
        SsoSignupPresentationPolicy.cancellationDecision(
            username: username,
            agreesToTerms: agreesToTerms,
            agreesToPrivacy: agreesToPrivacy,
            isWorking: isWorking
        )
    }

    private var preventsInteractiveDismissal: Bool {
        cancellationDecision != .dismiss
    }

    @ViewBuilder
    private func policySection(
        title: String,
        policy: PolicyDTO,
        isAgreed: Binding<Bool>
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                Spacer()
                Button {
                    displayedPolicy = policy
                } label: {
                    HStack(spacing: 3) {
                        Text(oauthString("auth.oauth.signup.viewPolicy"))
                        Image(systemName: "arrow.right")
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.accent)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                policyText(policy.content)
                    .font(DPFont.light(size: 13, relativeTo: .caption))
                    .foregroundStyle(DPColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(height: 128)
            .background(DPColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(DPColor.borderInput)
            }

            Button {
                isAgreed.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isAgreed.wrappedValue ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(isAgreed.wrappedValue ? DPColor.accent : DPColor.textSecondary)
                    Text(oauthString("auth.oauth.signup.agree"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                    Text("*")
                        .foregroundStyle(DPColor.danger)
                    Spacer()
                }
                .frame(minHeight: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }

    private func loadPolicies() async {
        guard policies == nil else { return }
        do {
            let response = try await oauthClient.currentPolicies()
            guard response.terms != nil, response.privacy != nil else {
                errorKey = "auth.oauth.signup.policyError"
                return
            }
            policies = response
        } catch {
            errorKey = "auth.oauth.signup.policyError"
        }
    }

    private func policyText(_ content: String) -> Text {
        guard let markdown = try? AttributedString(markdown: content) else {
            return Text(content)
        }
        return Text(markdown)
    }

    private func policyTitle(for policy: PolicyDTO) -> String {
        switch policy.policyType {
        case .terms:
            oauthString("auth.oauth.signup.terms")
        case .privacy:
            oauthString("auth.oauth.signup.privacy")
        case .aiScheduleParsing, .unknown:
            oauthString("auth.oauth.signup.viewPolicy")
        }
    }

    private func requestCancellation() {
        switch cancellationDecision {
        case .dismiss:
            dismiss()
        case .confirmDiscard:
            isNameFocused = false
            showsDiscardConfirmation = true
        case .blocked:
            break
        }
    }

    private func submit() {
        guard canSubmit, let terms = policies?.terms, let privacy = policies?.privacy else { return }
        let trimmedName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        errorKey = nil
        Task {
            defer { isWorking = false }
            do {
                try await oauthClient.signup(
                    SsoSignupRequest(
                        uuid: uuid,
                        username: trimmedName,
                        termAgree: true,
                        privacyAgree: true,
                        termsVersion: terms.version,
                        privacyVersion: privacy.version
                    )
                )
                try await session.finishExternalLogin()
            } catch {
                errorKey = "auth.oauth.signup.error"
            }
        }
    }
}

func oauthString(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), table: "OAuth")
}
