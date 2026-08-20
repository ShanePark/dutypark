import SwiftUI

nonisolated struct DPFriendTagItem: Identifiable, Equatable, Sendable {
    let id: MemberID
    let name: String
    let team: String?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let isFamily: Bool
    let pinOrder: Int64?

    init(
        id: MemberID,
        name: String,
        team: String?,
        hasProfilePhoto: Bool,
        profilePhotoVersion: Int64,
        isFamily: Bool = false,
        pinOrder: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.team = team
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
        self.isFamily = isFamily
        self.pinOrder = pinOrder
    }
}

nonisolated enum DPFriendTagSelectionLogic {
    static func mergedItems(
        items: [DPFriendTagItem],
        preservedItems: [DPFriendTagItem],
        selection: Set<MemberID>
    ) -> [DPFriendTagItem] {
        var currentByID: [MemberID: DPFriendTagItem] = [:]
        for item in items {
            currentByID[item.id] = item
        }

        var merged = currentByID
        for item in preservedItems where selection.contains(item.id) && currentByID[item.id] == nil {
            merged[item.id] = item
        }

        return merged.values.sorted(by: precedes)
    }

    static func visibleItems(items: [DPFriendTagItem], query: String) -> [DPFriendTagItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !normalizedQuery.isEmpty else { return items }
        return items.filter { item in
            "\(item.name) \(item.team ?? "")".localizedLowercase.contains(normalizedQuery)
        }
    }

    static func sortedIDs(_ selection: Set<MemberID>) -> [MemberID] {
        selection.sorted()
    }

    /// Bounds of one portrait card. Every portrait rail in the app shares them so the schedule
    /// tag selector and the home friend list read as the same component rather than two that
    /// happen to look alike.
    static let minimumCardWidth: CGFloat = 60
    static let maximumCardWidth: CGFloat = 88

    /// Width of one portrait card so three of them plus a peek of the next always fit `availableWidth`.
    /// The peek is what makes the sideways scroll discoverable; the clamp keeps cards legible in a
    /// labelled schedule column and stops them stretching in a roomy sheet.
    static func cardWidth(
        availableWidth: CGFloat,
        spacing: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        let ideal = (availableWidth - spacing * 3) / 3.2
        return min(max(ideal, minimum), maximum)
    }

    private static func precedes(_ lhs: DPFriendTagItem, _ rhs: DPFriendTagItem) -> Bool {
        switch (lhs.pinOrder, rhs.pinOrder) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        if lhs.isFamily != rhs.isFamily { return lhs.isFamily }
        let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.id < rhs.id
    }
}

nonisolated enum DPFriendTagSelectorScrollAnchor: Hashable, Sendable {
    case selectionSummary
}

struct DPFriendTagSelector: View {
    let items: [DPFriendTagItem]
    let preservedItems: [DPFriendTagItem]
    @Binding var selection: Set<MemberID>
    let disabled: Bool
    private let onExpand: () -> Void
    private let isSearchFocusedBinding: Binding<Bool>?

    @State private var isExpanded: Bool
    @State private var query = ""
    @State private var railWidth: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

    /// Icon sizes scale with the `.subheadline`-relative labels they sit next to.
    @ScaledMetric(relativeTo: .subheadline) private var collapsedIconSize: CGFloat = 16
    /// The rail sizes its cards from the width it actually gets, between these bounds.
    @ScaledMetric(relativeTo: .subheadline) private var minimumCardWidth = DPFriendTagSelectionLogic.minimumCardWidth
    @ScaledMetric(relativeTo: .subheadline) private var maximumCardWidth = DPFriendTagSelectionLogic.maximumCardWidth
    @ScaledMetric(relativeTo: .caption) private var chipAvatarSize: CGFloat = 22

    private var cardWidth: CGFloat {
        guard railWidth > 0 else { return minimumCardWidth }
        return DPFriendTagSelectionLogic.cardWidth(
            availableWidth: railWidth - DPSpacing.small * 2,
            spacing: DPSpacing.small,
            minimum: minimumCardWidth,
            maximum: maximumCardWidth
        )
    }

    private var portraitWidth: CGFloat { cardWidth - DPSpacing.small }
    private var portraitHeight: CGFloat { portraitWidth * 4 / 3 }

    /// - Parameter isSearchFocused: mirrors the focus state of the internal search field so a
    ///   host form can keep the selector visible while the keyboard is up. The selector owns the
    ///   focus; this binding only reports it.
    init(
        items: [DPFriendTagItem],
        preservedItems: [DPFriendTagItem] = [],
        selection: Binding<Set<MemberID>>,
        disabled: Bool = false,
        isSearchFocused: Binding<Bool>? = nil,
        onExpand: @escaping () -> Void = {}
    ) {
        self.items = items
        self.preservedItems = preservedItems
        _selection = selection
        self.disabled = disabled
        self.onExpand = onExpand
        self.isSearchFocusedBinding = isSearchFocused
        _isExpanded = State(initialValue: !selection.wrappedValue.isEmpty)
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedSelector
            } else {
                collapsedButton
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            isSearchFocusedBinding?.wrappedValue = focused
        }
        .sensoryFeedback(trigger: selection) { previous, current in
            DPFriendTagFeedback.feedback(
                isEnabled: !disabled,
                previous: previous,
                current: current
            )
        }
    }

    private var collapsedButton: some View {
        Button {
            isExpanded = true
            onExpand()
        } label: {
            HStack(spacing: DPSpacing.compact) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: collapsedIconSize, weight: .semibold))
                    .foregroundStyle(DPColor.accent)
                    .frame(width: 40, height: 40)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(Circle())
                Text(localized("friendTag.title"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer(minLength: 0)
                if !selection.isEmpty {
                    Text(format("friendTag.selected", selection.count))
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(DPColor.accent)
                        .padding(.horizontal, DPSpacing.small)
                        .frame(minHeight: 28)
                        .background(DPColor.accentSoft, in: Capsule())
                }
            }
            .padding(.horizontal, DPSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary)
        }
        .disabled(disabled)
        .accessibilityLabel(localized("friendTag.expand"))
        .accessibilityValue(selection.isEmpty ? localized("friendTag.noneSelected") : format("friendTag.selected", selection.count))
    }

    private var expandedSelector: some View {
        VStack(spacing: DPSpacing.small) {
            searchField

            if railItems.isEmpty {
                Text(localized("friendTag.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            } else {
                rail
            }

            selectedStrip
                .id(DPFriendTagSelectorScrollAnchor.selectionSummary)
        }
        .padding(10)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary)
        }
    }

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            HStack(spacing: DPSpacing.small) {
                Text(format("friendTag.selected", selection.count))
                    .font(DPFont.bold(size: 12, relativeTo: .caption))
                    .foregroundStyle(DPColor.textSecondary)
                Spacer(minLength: 0)
                clearButton
                    .opacity(selection.isEmpty ? 0 : 1)
                    .accessibilityHidden(selection.isEmpty)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(selectedItems) { item in
                        chip(item)
                    }
                }
                .padding(.horizontal, 2)
            }
            // Reserve the chip rail before the first selection so picking a friend changes
            // only the rail's contents, never the form's height or scroll position.
            .frame(minHeight: chipAvatarSize + 16)
        }
        .padding(DPSpacing.small)
        .background(DPColor.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.accentBorder)
        }
    }

    private var rail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: DPSpacing.small) {
                ForEach(railItems) { item in
                    card(item)
                }
            }
            .padding(DPSpacing.small)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { railWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in railWidth = width }
            }
        }
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
    }

    private var searchField: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DPColor.textMuted)
            TextField(localized("friendTag.search"), text: $query)
                .font(DPTypography.label)
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
                .disabled(disabled)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.textMuted)
                .disabled(disabled)
                .accessibilityLabel(localized("friendTag.clearSearch"))
            }
        }
        .padding(.horizontal, DPSpacing.compact)
        .frame(minHeight: DPSize.minimumTouchTarget)
        .background(DPColor.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderInput)
        }
    }

    private var clearButton: some View {
        Button {
            selection.removeAll()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text(localized("friendTag.clearShort"))
                    .font(DPFont.bold(size: 11, relativeTo: .caption2))
            }
            .foregroundStyle(DPColor.textSecondary)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled || selection.isEmpty)
        .accessibilityLabel(localized("friendTag.clear"))
    }

    private func chip(_ item: DPFriendTagItem) -> some View {
        Button {
            selection.remove(item.id)
        } label: {
            HStack(spacing: 5) {
                chipAvatar(item)
                Text(item.name)
                    .font(DPFont.light(size: 12, relativeTo: .caption))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(.leading, 3)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, 3)
            .background(DPColor.backgroundCard, in: Capsule())
            .overlay {
                Capsule().stroke(DPColor.accentBorder)
            }
            // Keeps the tappable area at the 44pt target while the capsule stays chip-sized.
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(format("friendTag.remove", item.name))
    }

    private func card(_ item: DPFriendTagItem) -> some View {
        let selected = selection.contains(item.id)
        return Button {
            if selected { selection.remove(item.id) } else { selection.insert(item.id) }
        } label: {
            VStack(spacing: DPSpacing.extraSmall) {
                ZStack(alignment: .bottomTrailing) {
                    portrait(item)
                    if selected {
                        checkBadge
                    }
                }
                // No `minimumScaleFactor` on either line: a shrunk `Text` also shrinks its
                // line box, so a long name or team name would produce a shorter card.
                // Truncation keeps every line — and so every card — the same height.
                Text(item.name)
                    .font(DPFont.bold(size: 12, relativeTo: .caption))
                    .foregroundStyle(selected ? DPColor.accent : DPColor.textPrimary)
                    .lineLimit(1)
                Text(teamLine(item))
                    .font(DPFont.light(size: 10, relativeTo: .caption2))
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, DPSpacing.extraSmall)
            .frame(width: cardWidth)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(item.team.map { "\(item.name), \($0)" } ?? item.name)
        .accessibilityValue(selected ? localized("friendTag.selectedState") : localized("friendTag.notSelectedState"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Every card spends the team line, so a friend without a team keeps the slot blank
    /// instead of shrinking the card out of line with its neighbours. The blank slot is a
    /// non-breaking space because an empty `Text` collapses to no height at all.
    private func teamLine(_ item: DPFriendTagItem) -> String {
        guard let team = item.team, !team.isEmpty else { return "\u{00A0}" }
        return team
    }

    private var checkBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DPColor.textOnDark)
            .frame(width: 20, height: 20)
            .background(DPColor.accent, in: Circle())
            .overlay {
                Circle().stroke(DPColor.backgroundPrimary, lineWidth: 2)
            }
            .padding(DPSpacing.extraSmall)
    }

    @ViewBuilder
    private func portrait(_ item: DPFriendTagItem) -> some View {
        Group {
            if item.hasProfilePhoto {
                AsyncImage(url: profileURL(item)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    portraitFallback(item)
                }
            } else {
                portraitFallback(item)
            }
        }
        .frame(width: portraitWidth, height: portraitHeight)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
    }

    private func portraitFallback(_ item: DPFriendTagItem) -> some View {
        DPColor.backgroundTertiary
            .overlay {
                Text(String(item.name.prefix(1)))
                    .font(DPFont.bold(size: 22, relativeTo: .title3))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    @ViewBuilder
    private func chipAvatar(_ item: DPFriendTagItem) -> some View {
        if item.hasProfilePhoto {
            AsyncImage(url: profileURL(item)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                chipAvatarFallback(item)
            }
            .frame(width: chipAvatarSize, height: chipAvatarSize)
            .clipShape(Circle())
        } else {
            chipAvatarFallback(item)
        }
    }

    private func chipAvatarFallback(_ item: DPFriendTagItem) -> some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: chipAvatarSize, height: chipAvatarSize)
            .overlay {
                Text(String(item.name.prefix(1)))
                    .font(DPFont.bold(size: 10, relativeTo: .caption2))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    /// The rail only offers friends that can still be tagged; a stale pick stays removable through its chip.
    private var railItems: [DPFriendTagItem] {
        DPFriendTagSelectionLogic.visibleItems(items: currentItems, query: query)
    }

    private var selectedItems: [DPFriendTagItem] {
        allItems.filter { selection.contains($0.id) }
    }

    private var currentItems: [DPFriendTagItem] {
        DPFriendTagSelectionLogic.mergedItems(items: items, preservedItems: [], selection: [])
    }

    private var allItems: [DPFriendTagItem] {
        DPFriendTagSelectionLogic.mergedItems(
            items: items,
            preservedItems: preservedItems,
            selection: selection
        )
    }

    private func profileURL(_ item: DPFriendTagItem) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(item.id)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(item.profilePhotoVersion))
            ])
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, table: "Localizable")
    }

    private func format(_ key: String, _ argument: Int) -> String {
        String(format: localized(key), locale: AppLocalization.locale, argument)
    }

    private func format(_ key: String, _ argument: String) -> String {
        String(format: localized(key), locale: AppLocalization.locale, argument)
    }
}
