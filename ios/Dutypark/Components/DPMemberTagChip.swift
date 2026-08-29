import SwiftUI

/// One person, drawn as a tag: their photo and their name.
///
/// A tag names somebody, and a bare name is slow to recognise among several. Every
/// other surface that names a person shows their face, so tags carry one too, and
/// they carry the same one everywhere — a member reads identically in a calendar
/// cell, on a to-do card and in a detail sheet.
nonisolated struct DPMemberTagItem: Identifiable, Equatable, Sendable {
    let memberID: MemberID?
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64

    /// Tags can arrive without a member id — a schedule remembers who tagged it by
    /// name once that account is gone — so identity falls back to the name.
    var id: String { memberID.map(String.init) ?? "name:\(name)" }

    init(
        memberID: MemberID?,
        name: String,
        hasProfilePhoto: Bool = false,
        profilePhotoVersion: Int64 = 0
    ) {
        self.memberID = memberID
        self.name = name
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
    }

    init(_ member: MemberDTO) {
        self.init(
            memberID: member.id,
            name: member.name,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }

    init(_ member: MemberPreviewDTO) {
        self.init(
            memberID: member.id,
            name: member.name,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }
}

/// How much room the surface can spare for a tag.
nonisolated enum DPMemberTagSize: Sendable {
    /// A calendar month cell: a few points of height, several tags competing for it.
    case micro
    /// A list card, where a tag sits beside other supporting text.
    case compact
    /// A detail sheet, where the tag is content rather than a hint.
    case regular

    var avatarDiameter: CGFloat {
        switch self {
        case .micro: 12
        case .compact: 16
        case .regular: 20
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .micro: 9
        case .compact: 11
        case .regular: 12
        }
    }

    var relativeTextStyle: Font.TextStyle {
        switch self {
        case .micro: .caption2
        case .compact: .caption2
        case .regular: .caption
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .micro: 3
        case .compact: 5
        case .regular: 6
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .micro: 1
        case .compact: 2
        case .regular: 3
        }
    }

    var spacing: CGFloat {
        switch self {
        case .micro: 2
        case .compact: 3
        case .regular: 4
        }
    }

    /// A month cell cannot hold a full name next to two others, so it shows just
    /// enough of one to tell the tags apart. Wider surfaces show the whole name.
    var nameCharacterLimit: Int? {
        switch self {
        case .micro: 2
        case .compact, .regular: nil
        }
    }
}

nonisolated enum DPMemberTagPresentation {
    /// Shortens a name only when it would not fit, so a name already short enough
    /// never gains an ellipsis it does not need.
    static func displayName(_ name: String, limit: Int?) -> String {
        guard let limit, limit > 0 else { return name }
        let characters = Array(name)
        guard characters.count > limit + 1 else { return name }
        return String(characters.prefix(limit)) + "…"
    }

    /// The photo the tag draws, versioned so a changed photo defeats the year-long
    /// cache the endpoint asks for.
    static func profilePhotoURL(memberID: MemberID, version: Int64) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(version)),
            ])
    }
}

/// A member's photo, circular, falling back to the shared profile asset.
struct DPMemberAvatar: View {
    let item: DPMemberTagItem
    var diameter: CGFloat

    var body: some View {
        DPProfileAvatar(
            memberID: item.memberID,
            hasProfilePhoto: item.hasProfilePhoto,
            profilePhotoVersion: item.profilePhotoVersion,
            size: diameter
        )
        .accessibilityHidden(true)
    }
}

/// A single member tag.
struct DPMemberTagChip: View {
    let item: DPMemberTagItem
    var size: DPMemberTagSize = .regular

    var body: some View {
        HStack(spacing: size.spacing) {
            DPMemberAvatar(item: item, diameter: size.avatarDiameter)

            Text(DPMemberTagPresentation.displayName(item.name, limit: size.nameCharacterLimit))
                .font(DPFont.light(size: size.fontSize, relativeTo: size.relativeTextStyle))
                .foregroundStyle(DPColor.textSecondary)
                .lineLimit(1)
        }
        .padding(.leading, size.verticalPadding)
        .padding(.trailing, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(DPColor.backgroundCard, in: Capsule())
        .overlay { Capsule().stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
    }
}

/// Lays tags out in rows, wrapping onto the next one when a tag will not fit.
///
/// A calendar cell is 47pt wide on the smallest phone — narrower than two tags side by
/// side — so a row that cannot wrap either spills over the neighbouring day or loses
/// the tags to a clip. The web wraps in that same cell, pushing each row to its
/// trailing edge, and this reads the same.
struct DPMemberTagFlow: Layout {
    let spacing: CGFloat
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(ofWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(ofWidth: bounds.width, subviews: subviews) {
            var x = alignment == .trailing ? bounds.maxX - row.width : bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(ofWidth availableWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithTag = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            // A tag wider than the whole row still gets a row of its own rather than
            // being dropped, so an over-long name spills rather than vanishing.
            if !row.indices.isEmpty, widthWithTag > availableWidth {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }

        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// Member tags, wrapping across rows and trailing a `+N` once the count is capped.
struct DPMemberTagChips: View {
    let items: [DPMemberTagItem]
    var size: DPMemberTagSize = .regular
    /// How many tags to draw before collapsing the rest into a count. `nil` draws all.
    var limit: Int?
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        DPMemberTagFlow(spacing: size.spacing, alignment: alignment) {
            ForEach(visibleItems) { item in
                DPMemberTagChip(item: item, size: size)
            }

            if hiddenCount > 0 {
                Text(verbatim: "+\(hiddenCount)")
                    .font(DPFont.bold(size: size.fontSize, relativeTo: size.relativeTextStyle))
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.horizontal, size.horizontalPadding)
                    .padding(.vertical, size.verticalPadding + size.avatarDiameter / 2 - size.fontSize / 2)
                    .background(DPColor.backgroundCard, in: Capsule())
                    .overlay { Capsule().stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth) }
                    .accessibilityLabel(Text(verbatim: "+\(hiddenCount)"))
            }
        }
    }

    private var visibleItems: [DPMemberTagItem] {
        guard let limit, items.count > limit else { return items }
        return Array(items.prefix(limit))
    }

    private var hiddenCount: Int {
        guard let limit, items.count > limit else { return 0 }
        return items.count - limit
    }
}
