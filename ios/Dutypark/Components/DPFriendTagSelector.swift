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

    static func visibleItems(
        items: [DPFriendTagItem],
        query: String,
        selectedOnly: Bool,
        selection: Set<MemberID>
    ) -> [DPFriendTagItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return items.filter { item in
            let matchesSelection = !selectedOnly || selection.contains(item.id)
            let matchesQuery = normalizedQuery.isEmpty
                || "\(item.name) \(item.team ?? "")".localizedLowercase.contains(normalizedQuery)
            return matchesSelection && matchesQuery
        }
    }

    static func sortedIDs(_ selection: Set<MemberID>) -> [MemberID] {
        selection.sorted()
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

struct DPFriendTagSelector: View {
    let items: [DPFriendTagItem]
    let preservedItems: [DPFriendTagItem]
    @Binding var selection: Set<MemberID>
    let disabled: Bool

    @State private var isExpanded: Bool
    @State private var query = ""
    @State private var showsSelectedOnly = false

    /// Icon sizes scale with the `.subheadline`-relative labels they sit next to.
    @ScaledMetric(relativeTo: .subheadline) private var collapsedIconSize: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var selectionIconSize: CGFloat = 14

    init(
        items: [DPFriendTagItem],
        preservedItems: [DPFriendTagItem] = [],
        selection: Binding<Set<MemberID>>,
        disabled: Bool = false
    ) {
        self.items = items
        self.preservedItems = preservedItems
        _selection = selection
        self.disabled = disabled
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
    }

    private var collapsedButton: some View {
        Button {
            isExpanded = true
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
            HStack(spacing: 6) {
                searchField
                if !selection.isEmpty {
                    selectedOnlyButton
                    clearButton
                }
            }

            if visibleItems.isEmpty {
                Text(localized("friendTag.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)],
                        spacing: 1
                    ) {
                        ForEach(visibleItems) { item in
                            friendButton(item)
                        }
                    }
                }
                .frame(maxHeight: 146)
                .background(DPColor.borderPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            }
        }
        .padding(10)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary)
        }
    }

    private var searchField: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DPColor.textMuted)
            TextField(localized("friendTag.search"), text: $query)
                .font(DPTypography.label)
                .textInputAutocapitalization(.never)
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

    private var selectedOnlyButton: some View {
        Button {
            showsSelectedOnly.toggle()
        } label: {
            Text(format("friendTag.selected", selection.count))
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(showsSelectedOnly ? DPColor.textOnDark : DPColor.textPrimary)
                .padding(.horizontal, 8)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(showsSelectedOnly ? DPColor.accent : DPColor.accentSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(localized("friendTag.selectedOnly"))
        .accessibilityAddTraits(showsSelectedOnly ? .isSelected : [])
    }

    private var clearButton: some View {
        Button {
            selection.removeAll()
            showsSelectedOnly = false
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DPColor.textSecondary)
        .disabled(disabled)
        .accessibilityLabel(localized("friendTag.clear"))
    }

    private func friendButton(_ item: DPFriendTagItem) -> some View {
        let selected = selection.contains(item.id)
        return Button {
            if selected { selection.remove(item.id) } else { selection.insert(item.id) }
        } label: {
            HStack(spacing: DPSpacing.small) {
                avatar(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(DPFont.light(size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    if let team = item.team, !team.isEmpty {
                        Text(team)
                            .font(DPFont.light(size: 11, relativeTo: .caption))
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: selectionIconSize, weight: .semibold))
                        .foregroundStyle(DPColor.accent)
                }
            }
            .padding(.horizontal, DPSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? DPColor.accentSoftHover : DPColor.backgroundPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(item.team.map { "\(item.name), \($0)" } ?? item.name)
        .accessibilityValue(selected ? localized("friendTag.selectedState") : localized("friendTag.notSelectedState"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func avatar(_ item: DPFriendTagItem) -> some View {
        if item.hasProfilePhoto {
            AsyncImage(url: profileURL(item)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarFallback(item)
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        } else {
            avatarFallback(item)
        }
    }

    private func avatarFallback(_ item: DPFriendTagItem) -> some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: 24, height: 24)
            .overlay {
                Text(String(item.name.prefix(1)))
                    .font(DPFont.bold(size: 10, relativeTo: .caption2))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    private var visibleItems: [DPFriendTagItem] {
        DPFriendTagSelectionLogic.visibleItems(
            items: allItems,
            query: query,
            selectedOnly: showsSelectedOnly,
            selection: selection
        )
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
}
