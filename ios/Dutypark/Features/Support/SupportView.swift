import SwiftUI

nonisolated enum SupportLocalization {
    static func text(_ key: String) -> String {
        AppLocalization.string(key, table: "Support")
    }
}

/// Public contact point required by App Review 1.2: it explains how reporting and
/// blocking work and carries the inquiry form. Guests reach it from the landing screen,
/// members from the "more" menu with their account e-mail already filled in.
struct SupportView: View {
    private enum Field: Hashable {
        case email
        case subject
        case content
    }

    @StateObject private var model: SupportViewModel
    @FocusState private var focusedField: Field?

    init(
        prefilledEmail: String? = nil,
        repository: any SupportRepository = LiveSupportRepository()
    ) {
        _model = StateObject(
            wrappedValue: SupportViewModel(
                prefilledEmail: prefilledEmail,
                repository: repository
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DPSpacing.medium) {
                guidance
                if model.didSubmit {
                    confirmation
                } else {
                    form
                }
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundPrimary)
        .scrollDismissesKeyboard(.interactively)
        .dpKeyboardDismissToolbar()
        .navigationTitle(SupportLocalization.text("support.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.support")
    }

    private var guidance: some View {
        card {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text(verbatim: SupportLocalization.text("support.intro.title"))
                        .font(DPTypography.heading)
                        .foregroundStyle(DPColor.textPrimary)
                    Text(verbatim: SupportLocalization.text("support.intro.description"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                guidanceRow(
                    icon: "flag",
                    title: "support.guide.report.title",
                    description: "support.guide.report.description"
                )
                guidanceRow(
                    icon: "hand.raised",
                    title: "support.guide.block.title",
                    description: "support.guide.block.description"
                )
                guidanceRow(
                    icon: "clock.badge.checkmark",
                    title: "support.guide.policy.title",
                    description: "support.guide.policy.description"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DPSpacing.medium)
        }
    }

    private func guidanceRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DPColor.accent)
                .frame(width: DPSize.iconLarge)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(verbatim: SupportLocalization.text(title))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                Text(verbatim: SupportLocalization.text(description))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var form: some View {
        card {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text(verbatim: SupportLocalization.text("support.form.title"))
                        .font(DPTypography.heading)
                        .foregroundStyle(DPColor.textPrimary)
                    Text(verbatim: SupportLocalization.text("support.form.description"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                field(label: "support.form.email") {
                    TextField(
                        "",
                        text: $model.email,
                        prompt: Text(verbatim: SupportLocalization.text("support.form.email.placeholder"))
                    )
                    .font(DPTypography.body)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .subject }
                    .dpInputChrome(isFocused: focusedField == .email)
                    .accessibilityIdentifier("support.form.email")
                }

                field(label: "support.form.subject") {
                    TextField(
                        "",
                        text: $model.subject,
                        prompt: Text(verbatim: SupportLocalization.text("support.form.subject.placeholder"))
                    )
                    .font(DPTypography.body)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .subject)
                    .onChange(of: model.subject) { _, value in
                        if value.count > CreateInquiryRequest.subjectMaximumLength {
                            model.subject = String(value.prefix(CreateInquiryRequest.subjectMaximumLength))
                        }
                    }
                    .onSubmit { focusedField = .content }
                    .dpInputChrome(isFocused: focusedField == .subject)
                    .accessibilityIdentifier("support.form.subject")
                    counter(model.subject.count, limit: CreateInquiryRequest.subjectMaximumLength)
                }

                field(label: "support.form.content") {
                    TextEditor(text: $model.content)
                        .font(DPTypography.body)
                        .foregroundStyle(DPColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .content)
                        .frame(minHeight: 152)
                        .onChange(of: model.content) { _, value in
                            if value.count > CreateInquiryRequest.contentMaximumLength {
                                model.content = String(value.prefix(CreateInquiryRequest.contentMaximumLength))
                            }
                        }
                        .dpInputChrome(isFocused: focusedField == .content)
                        .overlay(alignment: .topLeading) {
                            if model.content.isEmpty {
                                Text(verbatim: SupportLocalization.text("support.form.content.placeholder"))
                                    .font(DPTypography.body)
                                    .foregroundStyle(DPColor.textMuted)
                                    .padding(.leading, DPChrome.inputHorizontalPadding + 4)
                                    .padding(.top, DPChrome.inputVerticalPadding + 7)
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityIdentifier("support.form.content")
                    counter(model.content.count, limit: CreateInquiryRequest.contentMaximumLength)
                }

                if let errorKey = model.errorKey {
                    Label {
                        Text(verbatim: SupportLocalization.text(errorKey))
                            .font(DPTypography.supporting)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .foregroundStyle(DPColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("support.form.error")
                }

                Button {
                    focusedField = nil
                    Task { await model.submit() }
                } label: {
                    Text(
                        verbatim: SupportLocalization.text(
                            model.isSubmitting ? "support.form.submitting" : "support.form.submit"
                        )
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("support.form.submit")
            }
            .padding(DPSpacing.medium)
        }
    }

    private var confirmation: some View {
        card {
            VStack(spacing: DPSpacing.compact) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(DPColor.success)
                    .accessibilityHidden(true)
                Text(verbatim: SupportLocalization.text("support.success.title"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(verbatim: SupportLocalization.text("support.success.message"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    model.startNewInquiry()
                } label: {
                    Text(verbatim: SupportLocalization.text("support.success.newInquiry"))
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .padding(.top, DPSpacing.extraSmall)
                .accessibilityIdentifier("support.success.newInquiry")
            }
            .frame(maxWidth: .infinity)
            .padding(DPSpacing.large)
        }
        .accessibilityIdentifier("support.success")
    }

    private func field<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(verbatim: SupportLocalization.text(label))
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
            content()
        }
    }

    private func counter(_ count: Int, limit: Int) -> some View {
        Text(verbatim: "\(count)/\(limit)")
            .font(DPTypography.caption)
            .foregroundStyle(count >= limit ? DPColor.danger : DPColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            }
    }
}
