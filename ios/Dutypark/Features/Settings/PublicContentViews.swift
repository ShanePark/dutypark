import SwiftUI

struct PublicGuideView: View {
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @StateObject private var model: PublicGuideViewModel
    @State private var expandedSections: Set<String> = []
    private let fallbackTitle: String

    init(
        fallbackTitle: String = SettingsLocalization.string("settings.guide"),
        service: any PublicContentServicing = PublicContentService()
    ) {
        self.fallbackTitle = fallbackTitle
        _model = StateObject(wrappedValue: PublicGuideViewModel(service: service))
    }

    var body: some View {
        Group {
            if let content = model.content {
                guide(content)
            } else if model.hasError {
                ContentUnavailableView {
                    Label(
                        SettingsLocalization.string("settings.guide.loadError.title"),
                        systemImage: "wifi.exclamationmark"
                    )
                } description: {
                    Text(SettingsLocalization.string("settings.guide.loadError.message"))
                } actions: {
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        Task { await model.load(locale: locale) }
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .accessibilityIdentifier("guide.error")
            } else {
                // The `else` branch must stay unconditional: before `.task` runs the model is
                // neither loading nor failed, and an empty `Group` would drop the modifiers
                // below - including the `.task` that starts the load.
                ProgressView(SettingsLocalization.string("settings.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("guide.loading")
            }
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(model.content?.title ?? fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: locale) {
            await model.load(locale: locale)
        }
        .onChange(of: model.content?.contentVersion) { _, _ in
            if expandedSections.isEmpty, let first = model.content?.sections.first {
                expandedSections.insert(first.id)
            }
        }
        .accessibilityIdentifier("screen.nativeGuide")
    }

    private var locale: String {
        PublicContentLocaleResolver.locale(languageCode: languageCode)
    }

    private func guide(_ content: PublicGuideContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DPSpacing.medium) {
                HStack(alignment: .top, spacing: DPSpacing.compact) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DPColor.textOnDark)
                        .frame(width: 48, height: 48)
                        .background(DPColor.accent, in: RoundedRectangle(cornerRadius: DPRadius.large))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text(verbatim: content.title)
                            .font(DPTypography.pageTitle)
                            .foregroundStyle(DPColor.textPrimary)
                        Text(verbatim: content.description)
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: DPSpacing.small) {
                    Button(content.actions.expandAll) {
                        expandedSections = Set(content.sections.map(\.id))
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .accessibilityIdentifier("guide.expandAll")

                    Button(content.actions.collapseAll) {
                        expandedSections.removeAll()
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .accessibilityIdentifier("guide.collapseAll")
                }

                ForEach(content.sections) { section in
                    PublicGuideSectionView(
                        section: section,
                        isExpanded: Binding(
                            get: { expandedSections.contains(section.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert(section.id)
                                } else {
                                    expandedSections.remove(section.id)
                                }
                            }
                        )
                    )
                }

                Label {
                    Text(verbatim: content.footer)
                } icon: {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(DPColor.accent)
                }
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .padding(DPSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DPColor.accentSoft, in: RoundedRectangle(cornerRadius: DPRadius.large))
                .accessibilityIdentifier("guide.footer")
            }
            .padding(DPSpacing.medium)
        }
        .refreshable { await model.load(locale: locale) }
    }
}

private struct PublicGuideSectionView: View {
    let section: PublicGuideSection
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                Text(verbatim: section.summary)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(section.cards) { card in
                    PublicGuideCardView(card: card)
                }
            }
            .padding(.top, DPSpacing.medium)
        } label: {
            let presentation = PublicContentPresentation.guideVisual(
                icon: section.icon,
                tone: section.tone
            )
            Label {
                Text(verbatim: section.title)
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: presentation.symbol)
                    .foregroundStyle(presentation.tone.color)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .tint(DPColor.textMuted)
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard, in: RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .accessibilityIdentifier("guide.section.\(section.id)")
    }
}

private struct PublicGuideCardView: View {
    let card: PublicGuideCard

    var body: some View {
        let presentation = PublicContentPresentation.guideVisual(icon: card.icon, tone: card.tone)
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Label {
                Text(verbatim: card.title)
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: presentation.symbol)
                    .foregroundStyle(presentation.tone.color)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DPSpacing.small) {
                ForEach(Array(card.items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                        Text("•")
                            .foregroundStyle(presentation.tone.color)
                            .accessibilityHidden(true)
                        Text(verbatim: item)
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("guide.card.\(card.id).item.\(index)")
                }
            }
        }
        .padding(DPSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide.card.\(card.id)")
    }
}

struct PublicReleaseNotesView: View {
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @StateObject private var model: PublicReleaseNotesViewModel

    init(service: any PublicContentServicing = PublicContentService()) {
        _model = StateObject(wrappedValue: PublicReleaseNotesViewModel(service: service))
    }

    var body: some View {
        Group {
            if model.isLoading, model.items.isEmpty {
                ProgressView(SettingsLocalization.string("settings.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("releaseNotes.loading")
            } else if model.hasError, model.items.isEmpty {
                ContentUnavailableView {
                    Label(
                        SettingsLocalization.string("settings.guide.loadError.title"),
                        systemImage: "wifi.exclamationmark"
                    )
                } description: {
                    Text(SettingsLocalization.string("settings.guide.loadError.message"))
                } actions: {
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        Task { await model.load(locale: locale) }
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .accessibilityIdentifier("releaseNotes.error")
            } else {
                notes
            }
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(model.labels?.title ?? SettingsLocalization.string("settings.releaseNotes"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: locale) { await model.load(locale: locale) }
        .accessibilityIdentifier("screen.nativeReleaseNotes")
    }

    private var locale: String {
        PublicContentLocaleResolver.locale(languageCode: languageCode)
    }

    private var notes: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DPSpacing.medium) {
                if let labels = model.labels {
                    Text(verbatim: labels.countText(model.totalElements))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .accessibilityIdentifier("releaseNotes.count")
                }

                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, note in
                    PublicReleaseNoteCard(
                        note: note,
                        labels: model.labels,
                        isLatest: index == 0
                    )
                }

                if model.nextPageHasError {
                    Label(
                        SettingsLocalization.string("settings.guide.loadError.message"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
                    .frame(maxWidth: .infinity)
                }

                if model.hasNext {
                    Button {
                        Task { await model.loadNextPage() }
                    } label: {
                        if model.isLoadingNextPage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(model.labels?.loadMore ?? "", systemImage: "chevron.down")
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .disabled(model.isLoadingNextPage)
                    .accessibilityIdentifier("releaseNotes.loadMore")
                }
            }
            .padding(DPSpacing.medium)
        }
        .refreshable { await model.load(locale: locale) }
    }
}

private struct PublicReleaseNoteCard: View {
    let note: PublicReleaseNote
    let labels: PublicReleaseNoteLabels?
    let isLatest: Bool

    var body: some View {
        let presentation = PublicContentPresentation.releaseCategory(note.category)
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                Image(systemName: presentation.symbol)
                    .foregroundStyle(presentation.tone.color)
                    .frame(width: 28, height: 28)
                    .background(presentation.tone.softColor, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    HStack(spacing: DPSpacing.small) {
                        Text(verbatim: note.version)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                        if isLatest, let latest = labels?.latest {
                            Text(verbatim: latest)
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.accent)
                                .padding(.horizontal, DPSpacing.small)
                                .padding(.vertical, 2)
                                .background(DPColor.accentSoft, in: Capsule())
                        }
                    }
                    Text(verbatim: note.title)
                        .font(DPTypography.heading)
                        .foregroundStyle(DPColor.textPrimary)
                }
                Spacer(minLength: 0)
            }

            Text(verbatim: note.summary)
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(note.changes.enumerated()), id: \.offset) { _, change in
                HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DPTypography.caption)
                        .foregroundStyle(presentation.tone.color)
                        .accessibilityHidden(true)
                    Text(verbatim: change)
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: DPSpacing.small) {
                Text(verbatim: note.date.replacingOccurrences(of: "-", with: "."))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)

                Text(verbatim: labels?.categoryLabels[note.category] ?? note.category)
                    .font(DPTypography.caption)
                    .foregroundStyle(presentation.tone.color)

                if !note.areas.isEmpty {
                    Text(verbatim: [
                        labels?.areas,
                        note.areas.map { labels?.areaLabels[$0] ?? $0 }.joined(separator: " · "),
                    ].compactMap { $0 }.joined(separator: ": "))
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let url = note.externalURL {
                    Link(destination: url) {
                        Label(
                            labels?.prText(note.pr) ?? String(note.pr),
                            systemImage: "arrow.up.right.square"
                        )
                            .font(DPTypography.caption)
                            .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .accessibilityIdentifier("releaseNotes.pr.\(note.pr)")
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard, in: RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("releaseNotes.item.\(note.id)")
    }
}

private extension PublicContentTone {
    var color: Color {
        switch self {
        case .accent: DPColor.accent
        case .accentLight: DPColor.accentHover
        case .success: DPColor.success
        case .warning: DPColor.warning
        case .danger: DPColor.danger
        case .neutral: DPColor.textSecondary
        case .muted: DPColor.textMuted
        }
    }

    var softColor: Color {
        switch self {
        case .accent: DPColor.accentSoft
        case .accentLight: DPColor.accentSoft
        case .success: DPColor.successSoft
        case .warning: DPColor.warningSoft
        case .danger: DPColor.dangerSoft
        case .neutral: DPColor.backgroundTertiary
        case .muted: DPColor.backgroundTertiary
        }
    }
}
