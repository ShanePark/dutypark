import Combine
import Foundation

nonisolated enum VisibilityAudienceScope: String, Hashable, Sendable {
    case calendar
    case schedule
}

nonisolated struct VisibilityAudienceContext: Hashable, Sendable {
    let ownerID: MemberID
    let visibility: Visibility
    let scope: VisibilityAudienceScope

    var isRestricted: Bool { visibility == .friends || visibility == .family }
}

nonisolated struct VisibilityAudienceSnapshot: Sendable {
    let ownerID: MemberID
    let calendarVisibility: Visibility
    let friends: [FriendDTO]
}

nonisolated enum VisibilityAudiencePolicy {
    /// This is relationship-based access, not an exhaustive ACL. Tags and privileges remain separate.
    static func members(
        in snapshot: VisibilityAudienceSnapshot,
        context: VisibilityAudienceContext
    ) -> [FriendDTO] {
        guard context.isRestricted, snapshot.ownerID == context.ownerID else { return [] }
        var seen = Set<MemberID>()
        return snapshot.friends.filter { friend in
            guard friend.id != context.ownerID, seen.insert(friend.id).inserted else { return false }
            if context.visibility == .family && !friend.isFamily { return false }
            if context.scope == .schedule {
                switch snapshot.calendarVisibility {
                case .publicAccess, .friends: break
                case .family: if !friend.isFamily { return false }
                case .privateAccess, .unknown: return false
                }
            }
            return true
        }
    }

    static func search(_ members: [FriendDTO], query: String, locale: Locale) -> [FriendDTO] {
        func normalized(_ value: String) -> String {
            value.precomposedStringWithCompatibilityMapping
                .folding(options: [.caseInsensitive], locale: locale)
        }
        let needle = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return members.filter { needle.isEmpty || normalized($0.name).contains(needle) }
            .sorted {
                let comparison = $0.name.compare($1.name, options: [.caseInsensitive, .numeric], locale: locale)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }
    }

    static func calendarRestricts(
        _ snapshot: VisibilityAudienceSnapshot,
        context: VisibilityAudienceContext
    ) -> Bool {
        context.scope == .schedule && (
            snapshot.calendarVisibility == .privateAccess ||
            (snapshot.calendarVisibility == .family && context.visibility == .friends)
        )
    }
}

@MainActor
final class VisibilityAudienceModel: ObservableObject {
    enum Status: Equatable { case idle, loading, ready, error }
    typealias Loader = @Sendable () async throws -> VisibilityAudienceSnapshot

    @Published private(set) var status: Status = .idle
    @Published private(set) var context: VisibilityAudienceContext?
    @Published private(set) var snapshot: VisibilityAudienceSnapshot?
    private var generation = 0
    private let loader: Loader

    init(loader: @escaping Loader = VisibilityAudienceModel.fetchSnapshot) {
        self.loader = loader
    }

    func reset() {
        generation &+= 1
        status = .idle
        context = nil
        snapshot = nil
    }

    func load(_ requested: VisibilityAudienceContext) async {
        reset()
        guard requested.ownerID > 0, requested.isRestricted, !Task.isCancelled else { return }
        context = requested
        status = .loading
        let requestGeneration = generation
        do {
            let value = try await loader()
            guard generation == requestGeneration, context == requested, !Task.isCancelled else { return }
            guard value.ownerID == requested.ownerID else { throw APIError.invalidResponse }
            snapshot = value
            status = .ready
        } catch {
            guard generation == requestGeneration, context == requested, !Task.isCancelled else { return }
            snapshot = nil
            status = .error
        }
    }

    func members(for requested: VisibilityAudienceContext) -> [FriendDTO] {
        guard context == requested, status == .ready, let snapshot else { return [] }
        return VisibilityAudiencePolicy.members(in: snapshot, context: requested)
    }

    func calendarRestricts(_ requested: VisibilityAudienceContext) -> Bool {
        guard context == requested, status == .ready, let snapshot else { return false }
        return VisibilityAudiencePolicy.calendarRestricts(snapshot, context: requested)
    }

    nonisolated static func fetchSnapshot() async throws -> VisibilityAudienceSnapshot {
        async let member: MemberDTO = APIClient.shared.request("members/me")
        async let friends: [FriendDTO] = APIClient.shared.request("friends")
        let (owner, relations) = try await (member, friends)
        guard let ownerID = owner.id else { throw APIError.invalidResponse }
        return VisibilityAudienceSnapshot(ownerID: ownerID, calendarVisibility: owner.calendarVisibility, friends: relations)
    }
}
