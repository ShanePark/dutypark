import SwiftUI

/// The member-only half of the support screen: every inquiry the signed-in member sent,
/// with the administrator's answer once it has been written. Rows expand in place so the
/// full text and the reply stay on the same screen as the form tab.
struct MyInquiryListView: View {
    @ObservedObject var model: SupportViewModel
    @State private var expandedInquiryID: UUID?

    var body: some View {
        SupportCard {
            LazyVStack(spacing: 0) {
                content
            }
        }
        .task { await model.loadInquiriesIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingInquiries && model.inquiries.isEmpty {
            Text(verbatim: SupportLocalization.text("support.history.loading"))
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.extraLarge)
                .accessibilityIdentifier("support.history.loading")
        } else if model.inquiryLoadFailed && model.inquiries.isEmpty {
            VStack(spacing: DPSpacing.compact) {
                Text(verbatim: SupportLocalization.text("support.history.loadFailed"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await model.loadInquiries() }
                } label: {
                    Text(verbatim: SupportLocalization.text("support.history.retry"))
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .accessibilityIdentifier("support.history.retry")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DPSpacing.extraLarge)
            .padding(.horizontal, DPSpacing.medium)
        } else if model.inquiries.isEmpty {
            VStack(spacing: DPSpacing.compact) {
                Image(systemName: "tray")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DPColor.textMuted.opacity(0.5))
                    .accessibilityHidden(true)

                Text(verbatim: SupportLocalization.text("support.history.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)

                Button {
                    model.selectedTab = .form
                } label: {
                    Text(verbatim: SupportLocalization.text("support.history.emptyAction"))
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .accessibilityIdentifier("support.history.emptyAction")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DPSpacing.extraLarge)
            .padding(.horizontal, DPSpacing.medium)
            .accessibilityIdentifier("support.history.empty")
        } else {
            ForEach(Array(model.inquiries.enumerated()), id: \.element.id) { index, inquiry in
                row(inquiry)

                if index < model.inquiries.count - 1 || model.hasMoreInquiries {
                    Divider()
                        .overlay(DPColor.borderPrimary)
                }
            }

            if model.hasMoreInquiries {
                loadMoreButton
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await model.loadMoreInquiries() }
        } label: {
            Group {
                if model.isLoadingMoreInquiries {
                    ProgressView()
                        .tint(DPColor.textSecondary)
                } else {
                    Text(verbatim: SupportLocalization.text("support.history.loadMore"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textSecondary)
                }
            }
            .padding(.horizontal, DPSpacing.large)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(
                DPColor.backgroundTertiary,
                in: RoundedRectangle(cornerRadius: DPRadius.standard)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.isLoadingMoreInquiries)
        .frame(maxWidth: .infinity)
        .padding(DPSpacing.medium)
        .accessibilityIdentifier("support.history.loadMore")
    }

    @ViewBuilder
    private func row(_ inquiry: MyInquiryDTO) -> some View {
        let isExpanded = expandedInquiryID == inquiry.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedInquiryID = isExpanded ? nil : inquiry.id
            } label: {
                HStack(alignment: .top, spacing: DPSpacing.compact) {
                    VStack(alignment: .leading, spacing: DPSpacing.small) {
                        Text(verbatim: MyInquiryPresentation.subjectText(inquiry))
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: DPSpacing.small) {
                            badge(
                                MyInquiryPresentation.statusKey(inquiry.status),
                                foreground: inquiry.status == .closed
                                    ? DPColor.textSecondary
                                    : DPColor.accentHover,
                                background: inquiry.status == .closed
                                    ? DPColor.backgroundTertiary
                                    : DPColor.accentSoft
                            )
                            badge(
                                MyInquiryPresentation.answerStateKey(inquiry),
                                foreground: inquiry.hasAnswer
                                    ? DPColor.successHover
                                    : DPColor.warningHover,
                                background: inquiry.hasAnswer
                                    ? DPColor.successSoft
                                    : DPColor.warningSoft
                            )
                            Text(verbatim: MyInquiryPresentation.date(inquiry.createdAt))
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textMuted)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DPColor.textMuted)
                        .accessibilityHidden(true)
                }
                .padding(DPSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("support.history.row")

            if isExpanded {
                detail(inquiry)
            }
        }
    }

    private func detail(_ inquiry: MyInquiryDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(verbatim: SupportLocalization.text("support.form.content"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                Text(verbatim: inquiry.content)
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .overlay(DPColor.borderPrimary)

            if let answer = inquiry.answerText {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                        Text(verbatim: SupportLocalization.text("support.history.answerTitle"))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                        Spacer(minLength: 0)
                        if let answeredAt = inquiry.answeredAt {
                            Text(verbatim: MyInquiryPresentation.date(answeredAt))
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textMuted)
                        }
                    }
                    Text(verbatim: answer)
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DPSpacing.compact)
                .background(
                    DPColor.backgroundSecondary,
                    in: RoundedRectangle(cornerRadius: DPRadius.standard)
                )
                .accessibilityIdentifier("support.history.answer")
            } else {
                Text(verbatim: SupportLocalization.text("support.history.pendingAnswer"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("support.history.pendingAnswer")
            }
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.bottom, DPSpacing.medium)
    }

    private func badge(
        _ key: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Text(verbatim: SupportLocalization.text(key))
            .font(DPTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, DPSpacing.extraSmall)
            .background(background, in: Capsule())
    }
}
