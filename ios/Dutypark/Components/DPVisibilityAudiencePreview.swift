import SwiftUI

nonisolated enum VisibilityAudienceLocalization {
    static func string(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "VisibilityAudience", locale: locale)
    }
}

struct DPVisibilityAudiencePreview: View {
    let ownerID: MemberID
    let visibility: Visibility
    var scope: VisibilityAudienceScope = .calendar
    @Environment(\.locale) private var locale
    @StateObject private var model = VisibilityAudienceModel()
    @State private var isExpanded = false
    @State private var query = ""
    @State private var retryGeneration = 0

    private struct Request: Hashable {
        let context: VisibilityAudienceContext
        let expanded: Bool
        let retry: Int
    }

    private var context: VisibilityAudienceContext {
        VisibilityAudienceContext(ownerID: ownerID, visibility: visibility, scope: scope)
    }
    private var members: [FriendDTO] { model.members(for: context) }
    private var visibleMembers: [FriendDTO] {
        VisibilityAudiencePolicy.search(members, query: query, locale: locale)
    }
    private var status: VisibilityAudienceModel.Status {
        model.context == context ? model.status : .idle
    }
    private func text(_ key: String) -> String { VisibilityAudienceLocalization.string(key) }
    private func countText(_ count: Int) -> String {
        text("count").replacingOccurrences(of: "{count}", with: count.formatted(.number.locale(locale)))
    }

    var body: some View {
        if context.isRestricted {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isExpanded.toggle()
                    query = ""
                    if !isExpanded { model.reset() }
                    DPHapticCenter.shared.emit(.selection)
                } label: {
                    HStack(spacing: DPSpacing.small) {
                        Image(systemName: visibility == .family ? "house" : "person.2")
                        Text(text(isExpanded ? "close" : "open"))
                            .font(DPTypography.bodyMedium)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: DPSpacing.extraSmall)
                        if isExpanded && status == .ready {
                            Text(countText(members.count))
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textSecondary)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .padding(.horizontal, DPSpacing.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.accent)
                .accessibilityValue(text(isExpanded ? "expanded" : "collapsed"))
                .accessibilityIdentifier("visibilityAudience.toggle")

                if isExpanded {
                    Divider()
                    details
                        .padding(DPSpacing.medium)
                }
            }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
            .task(id: Request(context: context, expanded: isExpanded, retry: retryGeneration)) {
                guard isExpanded else { model.reset(); return }
                await model.load(context)
            }
            .onChange(of: context) { _, _ in
                isExpanded = false
                query = ""
                model.reset()
            }
            .onChange(of: model.status) { _, newStatus in
                if isExpanded, model.context == context, newStatus == .error {
                    DPHapticCenter.shared.emit(.warning)
                }
            }
            .onDisappear { model.reset() }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            Text(text(visibility == .family ? "familyTitle" : "friendsTitle"))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(text(visibility == .family ? "familyDescription" : "friendsDescription"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            switch status {
            case .idle, .loading:
                HStack(spacing: DPSpacing.small) {
                    ProgressView()
                    Text(text("loading")).font(DPTypography.supporting)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .accessibilityElement(children: .combine)
            case .error:
                VStack(spacing: DPSpacing.small) {
                    Text(text("error"))
                        .font(DPTypography.supporting)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(text("retry")) { retryGeneration &+= 1 }
                        .buttonStyle(DPSecondaryButtonStyle())
                        .accessibilityIdentifier("visibilityAudience.retry")
                }
                .frame(maxWidth: .infinity)
            case .ready:
                audienceList
            }

            Divider()
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(text("readOnly"))
                Text(text("relationshipNote"))
                Text(text(scope == .schedule ? "scheduleNote" : "calendarNote"))
            }
            .font(DPTypography.caption)
            .foregroundStyle(DPColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var audienceList: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            if model.calendarRestricts(context) {
                Label(text("restricted"), systemImage: "info.circle")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DPSpacing.small)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
            }
            if members.count >= 8 {
                HStack(spacing: DPSpacing.small) {
                    Image(systemName: "magnifyingglass").foregroundStyle(DPColor.textMuted)
                    TextField(text("search"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel(text("search"))
                        .accessibilityIdentifier("visibilityAudience.search")
                }
                .font(DPTypography.body)
                .dpInputChrome()
            }
            if visibleMembers.isEmpty {
                Text(text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "empty" : "noResults"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DPSpacing.small) {
                        ForEach(visibleMembers, id: \.id) { person in
                            HStack(alignment: .center, spacing: DPSpacing.compact) {
                                DPProfileAvatar(memberID: person.id, hasProfilePhoto: person.hasProfilePhoto, profilePhotoVersion: person.profilePhotoVersion, size: 32)
                                    .accessibilityHidden(true)
                                Text(verbatim: person.name)
                                    .font(DPTypography.body)
                                    .foregroundStyle(DPColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(text(person.isFamily ? "family" : "friend"))
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textSecondary)
                                    .padding(.horizontal, DPSpacing.small)
                                    .padding(.vertical, DPSpacing.extraSmall)
                                    .background(DPColor.backgroundSecondary)
                                    .clipShape(Capsule())
                            }
                            .frame(minHeight: 44)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxHeight: 260)
                .fixedSize(horizontal: false, vertical: true)
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("visibilityAudience.list")
            }
        }
    }
}
