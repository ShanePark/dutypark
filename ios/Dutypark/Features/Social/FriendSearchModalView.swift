import SwiftUI

struct FriendSearchModalView: View {
    @ObservedObject var viewModel: SocialViewModel
    @State private var keyword = ""
    @FocusState private var focusedField: Field?

    let availableSize: CGSize
    /// The hosting screen owns the send-request confirmation so it stays beside
    /// the screen's other confirmations.
    let onSelectCandidate: (MemberPreviewDTO) -> Void
    let onDismiss: () -> Void

    private enum Field { case keyword }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: min(availableSize.height, 620),
            scrollTarget: focusedField
        ) {
            modalHeader
        } content: {
            modalBody
        } footer: {
            modalFooter
        }
        .onDisappear { viewModel.clearSearch() }
        .alert(
            social("social.error.title"),
            isPresented: Binding(
                get: { viewModel.errorKey != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(social("social.action.ok")) { viewModel.dismissError() }
        } message: {
            Text(social(viewModel.errorKey ?? "social.error.generic"))
        }
    }

    private var modalHeader: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DPColor.textOnDark)
                .frame(width: 40, height: 40)
                .background {
                    LinearGradient(
                        colors: [DPColor.accent, DPColor.accentHover],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))

            Text(social("social.search.title"))
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(social("social.action.close"))
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.compact)
        .background(DPColor.backgroundTertiary)
    }

    private var modalBody: some View {
        VStack(spacing: DPSpacing.medium) {
            searchBar

            if viewModel.isSearching {
                ProgressView(social("social.search.loading"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.accent)
                    .frame(maxWidth: .infinity, minHeight: 112)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: DPSpacing.compact) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(DPColor.borderSecondary)
                    Text(social("social.search.empty"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 152)
            } else {
                searchResults
            }
        }
        .padding(DPSpacing.medium)
    }

    private var searchBar: some View {
        HStack(spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DPColor.textMuted)
                TextField(social("social.search.prompt"), text: $keyword)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focusedField, equals: .keyword)
                    .onSubmit { search(page: 0) }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(DPColor.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                    .stroke(DPColor.borderInput, lineWidth: 1)
            }

            Button { search(page: 0) } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textOnDark)
                    .frame(width: 48, height: 48)
                    .background {
                        LinearGradient(
                            colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
            .opacity(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .id(Field.keyword)
    }

    private var searchResults: some View {
        VStack(spacing: DPSpacing.medium) {
            VStack(spacing: DPSpacing.small) {
                ForEach(viewModel.searchResults, id: \.id) { member in
                    HStack(spacing: DPSpacing.compact) {
                        SocialAvatar(member: member, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(DPFont.bold(size: 16, relativeTo: .body))
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            if let team = member.team, !team.isEmpty {
                                Text(team)
                                    .font(DPTypography.supporting)
                                    .foregroundStyle(DPColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: DPSpacing.small)
                        Button(social("social.action.sendRequest")) {
                            DPHapticCenter.shared.emit(.selection)
                            onSelectCandidate(member)
                        }
                        .font(DPFont.light(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(DPColor.textOnDark)
                        .padding(.horizontal, DPSpacing.compact)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.success)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                    }
                    .padding(DPSpacing.medium)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                }
            }

            if viewModel.searchTotalPages > 1 {
                HStack(spacing: DPSpacing.small) {
                    pageButton(systemImage: "chevron.left", disabled: viewModel.searchPage == 0) {
                        search(page: viewModel.searchPage - 1)
                    }
                    Text(
                        socialFormat(
                            "social.search.page",
                            String(viewModel.searchPage + 1),
                            String(viewModel.searchTotalPages)
                        )
                    )
                    .font(DPFont.light(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    pageButton(
                        systemImage: "chevron.right",
                        disabled: viewModel.searchPage + 1 >= viewModel.searchTotalPages
                    ) {
                        search(page: viewModel.searchPage + 1)
                    }
                }
            }

            Text(
                socialFormat(
                    "social.search.resultsSummary",
                    String(viewModel.searchPage + 1),
                    String(max(viewModel.searchTotalPages, 1)),
                    String(viewModel.searchTotalElements)
                )
            )
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.textSecondary)
        }
    }

    private func pageButton(
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DPColor.textPrimary)
                .frame(width: 40, height: 40)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                        .stroke(DPColor.borderPrimary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var modalFooter: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                onDismiss()
            } label: {
                Text(verbatim: social("social.action.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
        }
        .padding(DPSpacing.compact)
    }

    private func search(page: Int) {
        Task { await viewModel.search(keyword: keyword, page: page) }
    }
}

struct SearchCandidate: Identifiable {
    let member: MemberPreviewDTO
    var id: MemberID { member.id ?? -1 }
}
