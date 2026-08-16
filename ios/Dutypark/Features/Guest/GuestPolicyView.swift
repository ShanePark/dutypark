import SwiftUI
import Combine

@MainActor
private final class GuestPolicyViewModel: ObservableObject {
    let type: PolicyType
    private let api: GuestAPIProtocol

    @Published var policy: PolicyDTO?
    @Published var isLoading = false
    @Published var hasError = false

    init(type: PolicyType, api: GuestAPIProtocol = GuestAPI()) {
        self.type = type
        self.api = api
    }

    func load() async {
        isLoading = true
        hasError = false
        do {
            policy = try await api.policy(type)
        } catch {
            hasError = true
        }
        isLoading = false
    }
}

struct GuestPolicyView: View {
    @StateObject private var model: GuestPolicyViewModel

    init(type: PolicyType) {
        _model = StateObject(wrappedValue: GuestPolicyViewModel(type: type))
    }

    var body: some View {
        Group {
            if model.isLoading && model.policy == nil {
                ProgressView(GuestLocalization.text("guest.policy.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.hasError && model.policy == nil {
                VStack(spacing: DPSpacing.medium) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(DPColor.danger)
                    Text(title)
                        .font(.headline)
                    Text(GuestLocalization.text("guest.policy.error"))
                        .foregroundStyle(DPColor.textSecondary)
                    Button(GuestLocalization.text("guest.retry")) {
                        Task { await model.load() }
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                }
                .padding(DPSpacing.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let policy = model.policy {
                ScrollView {
                    VStack(alignment: .leading, spacing: DPSpacing.medium) {
                        DPLongFormDocument(content: policy.content)

                        Divider()

                        Text(GuestLocalization.format(
                            "guest.policy.version",
                            policy.version,
                            policy.effectiveDate.rawValue
                        ))
                        .font(.caption)
                        .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(.horizontal, DPLongFormDocumentLayout.horizontalPadding)
                    .padding(.vertical, DPLongFormDocumentLayout.verticalPadding)
                }
            } else {
                Text(GuestLocalization.text("guest.policy.unavailable"))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if model.policy == nil { await model.load() } }
    }

    private var title: String {
        GuestLocalization.text(model.type == .terms ? "guest.policy.terms" : "guest.policy.privacy")
    }
}
