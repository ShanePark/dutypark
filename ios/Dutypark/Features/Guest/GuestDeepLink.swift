import Foundation

nonisolated enum GuestRoute: Hashable, Sendable {
    case login
    case guide
    case terms
    case privacy
    case publicCalendar(MemberID)
}

nonisolated enum GuestDeepLink {
    static func route(
        from url: URL,
        allowedHost: String = "dutypark.o-r.kr"
    ) -> GuestRoute? {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == allowedHost.lowercased()
        else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if components == ["guide"] {
            return .guide
        }
        if components == ["terms"] {
            return .terms
        }
        if components == ["privacy"] {
            return .privacy
        }
        if components.count == 2, components[0] == "duty" {
            let rawID = components[1]
            guard let memberID = MemberID(rawID), memberID > 0 else { return nil }
            return .publicCalendar(memberID)
        }
        return nil
    }
}
