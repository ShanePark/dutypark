import SwiftUI

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(oauthString("auth.oauth.signup.name.placeholder"), text: $username)
                        .textContentType(.name)
                        .onChange(of: username) { _, value in
                            if value.count > 10 {
                                username = String(value.prefix(10))
                            }
                        }
                    Text(oauthString("auth.oauth.signup.name.help"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(oauthString("auth.oauth.signup.name"))
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
                    Section { ProgressView() }
                }

                if let errorKey {
                    Section {
                        Text(oauthString(errorKey))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("oauth.signup.error")
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(oauthString("auth.oauth.signup.submit"))
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("oauth.signup.submit")
                }
            }
            .navigationTitle(oauthString("auth.oauth.signup.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(oauthString("auth.oauth.cancel")) { dismiss() }
                }
            }
            .task { await loadPolicies() }
        }
        .accessibilityIdentifier("screen.oauth.signup")
    }

    private var canSubmit: Bool {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isWorking && !name.isEmpty && name.count <= 10 && agreesToTerms && agreesToPrivacy &&
            policies?.terms != nil && policies?.privacy != nil
    }

    @ViewBuilder
    private func policySection(
        title: String,
        policy: PolicyDTO,
        isAgreed: Binding<Bool>
    ) -> some View {
        Section {
            DisclosureGroup(oauthString("auth.oauth.signup.viewPolicy")) {
                ScrollView {
                    Text(policy.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 240)
            }
            Toggle(isOn: isAgreed) {
                Text(oauthString("auth.oauth.signup.agree"))
            }
        } header: {
            Text(title)
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
