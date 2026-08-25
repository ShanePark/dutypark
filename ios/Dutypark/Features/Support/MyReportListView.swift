import SwiftUI

/// The reporter's own view of every report they filed, with how far each one has been
/// handled. It deliberately stops at the outcome: what was actually done to the other
/// member is their private matter, so the row explains the state instead.
struct MyReportListView: View {
    @ObservedObject var model: SupportViewModel
    @State private var expandedReportID: UUID?
    @State private var reportPendingCancellation: MyReportDTO?

    var body: some View {
        SupportCard {
            LazyVStack(spacing: 0) {
                content
            }
        }
        .task { await model.loadReportsIfNeeded() }
        .dpConfirmation(
            item: $reportPendingCancellation,
            copy: { _ in
                DPConfirmationCopy(
                    title: SupportLocalization.text("support.reports.cancel.confirmTitle"),
                    message: SupportLocalization.text("support.reports.cancel.confirmMessage"),
                    confirmTitle: SupportLocalization.text("support.reports.cancel.confirmAction"),
                    cancelTitle: SupportLocalization.text("support.reports.cancel.keep"),
                    isDestructive: true
                )
            },
            confirm: { report, dismiss in
                // The row carries the in-flight state, so the panel can leave immediately
                // instead of holding the reporter in a modal.
                dismiss()
                Task { await model.cancelReport(id: report.id) }
            }
        )
        .alert(
            SupportLocalization.text("support.reports.cancel.errorTitle"),
            isPresented: Binding(
                get: { model.reportCancelErrorKey != nil },
                set: { if !$0 { model.reportCancelErrorKey = nil } }
            )
        ) {
            Button(SupportLocalization.text("support.reports.cancel.ok"), role: .cancel) {
                model.reportCancelErrorKey = nil
            }
        } message: {
            Text(verbatim: SupportLocalization.text(model.reportCancelErrorKey ?? ""))
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingReports && model.reports.isEmpty {
            Text(verbatim: SupportLocalization.text("support.reports.loading"))
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.extraLarge)
                .accessibilityIdentifier("support.reports.loading")
        } else if model.reportLoadFailed && model.reports.isEmpty {
            VStack(spacing: DPSpacing.compact) {
                Text(verbatim: SupportLocalization.text("support.reports.loadFailed"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await model.loadReports() }
                } label: {
                    Text(verbatim: SupportLocalization.text("support.reports.retry"))
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .accessibilityIdentifier("support.reports.retry")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DPSpacing.extraLarge)
            .padding(.horizontal, DPSpacing.medium)
        } else if model.reports.isEmpty {
            VStack(spacing: DPSpacing.compact) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DPColor.textMuted.opacity(0.5))
                    .accessibilityHidden(true)

                Text(verbatim: SupportLocalization.text("support.reports.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)

                Text(verbatim: SupportLocalization.text("support.reports.empty.description"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DPSpacing.extraLarge)
            .padding(.horizontal, DPSpacing.medium)
            .accessibilityIdentifier("support.reports.empty")
        } else {
            ForEach(Array(model.reports.enumerated()), id: \.element.id) { index, report in
                row(report)

                if index < model.reports.count - 1 || model.hasMoreReports {
                    Divider()
                        .overlay(DPColor.borderPrimary)
                }
            }

            if model.hasMoreReports {
                loadMoreButton
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await model.loadMoreReports() }
        } label: {
            Group {
                if model.isLoadingMoreReports {
                    ProgressView()
                        .tint(DPColor.textSecondary)
                } else {
                    Text(verbatim: SupportLocalization.text("support.reports.loadMore"))
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
        .disabled(model.isLoadingMoreReports)
        .frame(maxWidth: .infinity)
        .padding(DPSpacing.medium)
        .accessibilityIdentifier("support.reports.loadMore")
    }

    @ViewBuilder
    private func row(_ report: MyReportDTO) -> some View {
        let isExpanded = expandedReportID == report.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedReportID = isExpanded ? nil : report.id
                DPHapticCenter.shared.emit(.selection)
            } label: {
                HStack(alignment: .top, spacing: DPSpacing.compact) {
                    VStack(alignment: .leading, spacing: DPSpacing.small) {
                        Text(verbatim: report.reportedMemberName)
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: DPSpacing.small) {
                            statusBadge(report.status)
                            badge(
                                SupportLocalization.text(MyReportPresentation.targetTypeKey(report.targetType)),
                                foreground: DPColor.textSecondary,
                                background: DPColor.backgroundTertiary
                            )
                            Text(verbatim: MyInquiryPresentation.date(report.createdAt))
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textMuted)
                        }

                        Text(verbatim: MyReportPresentation.reasonText(report.reason))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textSecondary)
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
            .accessibilityIdentifier("support.reports.row")

            if isExpanded {
                detail(report)
            }
        }
    }

    private func detail(_ report: MyReportDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            summaryRow(
                label: "support.reports.target",
                value: "\(report.reportedMemberName) · "
                    + SupportLocalization.text(MyReportPresentation.targetTypeKey(report.targetType))
            )
            summaryRow(
                label: "support.reports.reason",
                value: MyReportPresentation.reasonText(report.reason)
            )

            if let detail = report.detail?.trimmingCharacters(in: .whitespacesAndNewlines),
               !detail.isEmpty {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text(verbatim: SupportLocalization.text("support.reports.detail"))
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                    Text(verbatim: detail)
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(DPColor.borderPrimary)

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                    Text(verbatim: SupportLocalization.text(MyReportPresentation.statusDescriptionKey(report.status)))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let resolvedAt = report.resolvedAt {
                        Text(verbatim: MyInquiryPresentation.date(resolvedAt))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                }

                if MyReportPresentation.showsPrivacyNotice(report) {
                    Text(verbatim: SupportLocalization.text("support.reports.privacyNotice"))
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DPSpacing.compact)
            .background(
                DPColor.backgroundSecondary,
                in: RoundedRectangle(cornerRadius: DPRadius.standard)
            )
            .accessibilityIdentifier("support.reports.status")

            if MyReportPresentation.canCancel(report) {
                cancelButton(report)
            }
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.bottom, DPSpacing.medium)
    }

    /// Withdrawing is undoing one's own report, not deleting someone else's data, so only the
    /// label carries the danger colour: the chrome stays the neutral outline every other
    /// secondary control uses, which separates it from "load more" without reading as a delete.
    private func cancelButton(_ report: MyReportDTO) -> some View {
        let isCanceling = model.isCancelingReport(report.id)

        return Button {
            reportPendingCancellation = report
        } label: {
            Group {
                if isCanceling {
                    ProgressView()
                        .tint(DPColor.danger)
                } else {
                    Text(verbatim: SupportLocalization.text("support.reports.cancel"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.danger)
                }
            }
            .padding(.horizontal, DPSpacing.large)
            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCanceling)
        .accessibilityIdentifier("support.reports.cancel")
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DPSpacing.compact) {
            Text(verbatim: SupportLocalization.text(label))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            Text(verbatim: value)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func statusBadge(_ status: ReportStatus) -> some View {
        badge(
            SupportLocalization.text(MyReportPresentation.statusKey(status)),
            foreground: statusForeground(status),
            background: statusBackground(status)
        )
    }

    /// A dismissed report is not a failure on the reporter's side, so it stays neutral
    /// rather than being coloured like an error. A withdrawn one was the reporter's own
    /// decision, which is no more of an error, so it reads the same way.
    private func statusForeground(_ status: ReportStatus) -> Color {
        switch status {
        case .open: DPColor.warningHover
        case .resolved: DPColor.successHover
        case .dismissed, .canceled: DPColor.textSecondary
        }
    }

    private func statusBackground(_ status: ReportStatus) -> Color {
        switch status {
        case .open: DPColor.warningSoft
        case .resolved: DPColor.successSoft
        case .dismissed, .canceled: DPColor.backgroundTertiary
        }
    }

    private func badge(
        _ text: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Text(verbatim: text)
            .font(DPTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, DPSpacing.extraSmall)
            .background(background, in: Capsule())
    }
}
