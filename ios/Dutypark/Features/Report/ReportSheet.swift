import SwiftUI

/// Shared report form for members, schedules and to-dos. Presented inside
/// `DPModalOverlay` by every entry point so the panel chrome matches the other modals.
struct ReportSheet: View {
    private enum Field: Hashable {
        case detail
    }

    @StateObject private var model: ReportViewModel
    @FocusState private var focusedField: Field?
    @State private var showsSuccess = false

    private let maximumHeight: CGFloat
    private let onDismissabilityChange: (Bool) -> Void
    /// Reported once, right before the sheet closes, when the accepted report also
    /// blocked the reported member. The host may no longer be allowed to show what it is
    /// showing, so it decides where the reporter lands.
    private let onBlocked: () -> Void
    private let dismiss: () -> Void

    init(
        target: ReportTarget,
        maximumHeight: CGFloat,
        repository: any ReportRepository = ReportAPIRepository(),
        onDismissabilityChange: @escaping (Bool) -> Void = { _ in },
        onBlocked: @escaping () -> Void = {},
        dismiss: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: ReportViewModel(target: target, repository: repository)
        )
        self.maximumHeight = maximumHeight
        self.onDismissabilityChange = onDismissabilityChange
        self.onBlocked = onBlocked
        self.dismiss = dismiss
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumHeight * ReportSheetLayout.maximumPanelHeightRatio,
            scrollTarget: focusedField
        ) {
            header
        } content: {
            form
        } footer: {
            footer
        }
        .accessibilityIdentifier("report.sheet")
        .onChange(of: model.isSubmitting) { _, isSubmitting in
            onDismissabilityChange(!isSubmitting)
        }
        .onDisappear { onDismissabilityChange(true) }
        .alert(
            ReportLocalization.text("report.success.title"),
            isPresented: $showsSuccess
        ) {
            // The outcome reaches the host while the cover is still up, so the host's own
            // dismissal callback already knows whether it has to leave.
            Button(ReportLocalization.text("report.ok"), role: .cancel) {
                if model.didBlock { onBlocked() }
                dismiss()
            }
        } message: {
            Text(verbatim: ReportLocalization.text("report.success.message"))
        }
        .alert(
            ReportLocalization.text("report.error.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(ReportLocalization.text("report.ok"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(verbatim: model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(verbatim: ReportLocalization.text("report.title"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            // The authorized `dismiss` closure comes from `DPModalOverlay`, which owns
            // the routine haptic for an immediate modal dismissal.
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isSubmitting)
            .accessibilityLabel(ReportLocalization.text("report.action.cancel"))
            .accessibilityIdentifier("report.cancel")
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.small)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            Label(model.targetLabel, systemImage: "flag")
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .accessibilityIdentifier("report.target")

            ReportFormSection(title: ReportLocalization.text("report.field.reason")) {
                Picker(selection: Binding(
                    get: { model.reason },
                    set: { model.selectReason($0) }
                )) {
                    ForEach(ReportReason.allCases) { reason in
                        Text(verbatim: ReportLocalization.text(reason.titleKey))
                            .tag(reason)
                    }
                } label: {
                    Text(verbatim: ReportLocalization.text("report.field.reason"))
                }
                .pickerStyle(.menu)
                .tint(DPColor.accent)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
                .dpInputChrome()
                .accessibilityIdentifier("report.reason")
            }

            ReportFormSection(title: ReportLocalization.text("report.field.detail")) {
                TextEditor(text: $model.detail)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .detail)
                    .frame(minHeight: 120)
                    .dpInputChrome(
                        isFocused: focusedField == .detail,
                        isInvalid: model.isDetailTooLong
                    )
                    .overlay(alignment: .topLeading) {
                        if model.detail.isEmpty {
                            Text(verbatim: ReportLocalization.text("report.field.detail.placeholder"))
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textMuted)
                                .padding(.leading, DPChrome.inputHorizontalPadding + 4)
                                .padding(.top, DPChrome.inputVerticalPadding + 7)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityIdentifier("report.detail")

                HStack(alignment: .top, spacing: DPSpacing.small) {
                    if model.requiresDetail {
                        Text(verbatim: ReportLocalization.text("report.field.detail.required"))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text(verbatim: "\(model.detailLength)/\(ReportSubmissionPolicy.detailLimit)")
                        .font(DPTypography.caption)
                        .foregroundStyle(model.isDetailTooLong ? DPColor.danger : DPColor.textMuted)
                }
            }
            .id(Field.detail)

            Toggle(isOn: Binding(
                get: { model.alsoBlock },
                set: { model.setAlsoBlock($0) }
            )) {
                Label(
                    ReportLocalization.text("report.field.alsoBlock"),
                    systemImage: "hand.raised"
                )
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
            }
            .tint(DPColor.accent)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .accessibilityIdentifier("report.alsoBlock")
        }
        .disabled(model.isSubmitting)
        .padding(DPSpacing.medium)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button(action: dismiss) {
                Text(verbatim: ReportLocalization.text("report.action.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(model.isSubmitting)

            Button(action: submit) {
                Group {
                    if model.isSubmitting {
                        ProgressView().tint(DPColor.textOnDark)
                    } else {
                        Text(verbatim: ReportLocalization.text("report.action.submit"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!model.canSubmit)
            .accessibilityIdentifier("report.submit")
        }
        .padding(DPSpacing.compact)
        .safeAreaPadding(.bottom, DPSpacing.extraSmall)
    }

    private func submit() {
        focusedField = nil
        Task {
            if await model.submit() {
                showsSuccess = true
            }
        }
    }

}

nonisolated enum ReportSheetLayout {
    static let maximumPanelHeightRatio: CGFloat = 0.9
}

private struct ReportFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(verbatim: title)
                .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textSecondary)
            content
        }
    }
}
