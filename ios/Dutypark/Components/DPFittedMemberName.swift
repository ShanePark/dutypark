import SwiftUI

/// Initials for a narrow name slot: "Shane Park" → "S.P". Only names of two or more
/// space-separated words that all start with a Latin letter have them; any other name
/// returns nil and keeps the slot's usual truncation.
/// Shares its test vectors with the web's `memberInitials` (docs/design/member-name-length.md).
nonisolated enum MemberNameInitials {
    static func initials(for name: String) -> String? {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard words.count >= 2,
              words.allSatisfy({ $0.range(of: "^\\p{Script=Latin}", options: .regularExpression) != nil })
        else { return nil }
        // A `Character` keeps a decomposed accent with its letter.
        return words.compactMap { $0.first.map { String($0).uppercased() } }.joined(separator: ".")
    }
}

/// A member's name in a slot sized for about three Hangul characters: the full name when
/// it fits, otherwise its initials, otherwise the name with the slot's own truncation.
/// Font, colour, `lineLimit` and `minimumScaleFactor` come from the call site; a name that
/// fits once shrunk to that factor counts as fitting.
struct DPFittedMemberName: View {
    let name: String
    @Environment(\.minimumScaleFactor) private var minimumScaleFactor

    var body: some View {
        if let initials = MemberNameInitials.initials(for: name) {
            DPFullNameIdealWidth {
                ViewThatFits(in: .horizontal) {
                    DPShrinkableIdealWidth(factor: minimumScaleFactor) {
                        Text(verbatim: name)
                    }
                    Text(verbatim: initials)
                }
                Text(verbatim: name).hidden()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: name))
        } else {
            Text(verbatim: name)
        }
    }
}

/// Reports its content's ideal width at the smallest size the text may shrink to, so
/// `ViewThatFits`, which compares ideal widths, keeps text that fits once shrunk.
private struct DPShrinkableIdealWidth: Layout {
    let factor: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        guard proposal.width == nil else { return content.sizeThatFits(proposal) }
        let ideal = content.sizeThatFits(proposal)
        return CGSize(width: ideal.width * factor, height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Lays out its first subview, but reports the second, hidden one's ideal width: the full
/// name's, so a slot sized to fit the name does not offer only its shrunk width.
private struct DPFullNameIdealWidth: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        guard proposal.width == nil else { return subviews[0].sizeThatFits(proposal) }
        let ideal = subviews[1].sizeThatFits(proposal)
        return CGSize(width: ideal.width, height: subviews[0].sizeThatFits(ProposedViewSize(width: ideal.width, height: proposal.height)).height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
