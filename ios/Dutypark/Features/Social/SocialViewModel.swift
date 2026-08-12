import Combine
import Foundation
import SwiftUI

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var friends: [DashboardFriendDetailDTO] = []
    @Published private(set) var receivedRequests: [FriendRequestDTO] = []
    @Published private(set) var sentRequests: [FriendRequestDTO] = []
    @Published private(set) var searchResults: [MemberPreviewDTO] = []
    @Published private(set) var searchPage = 0
    @Published private(set) var searchTotalPages = 0
    @Published private(set) var searchTotalElements: Int64 = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published private(set) var isPerformingAction = false
    @Published var errorKey: String?

    private let repository: any SocialRepository
    private let searchPageSize: Int
    private let onMutation: @MainActor (Bool) async -> Void
    private var pinnedOrderIDs: [MemberID]?

    init(
        repository: any SocialRepository = LiveSocialRepository(),
        searchPageSize: Int = 5,
        onMutation: @escaping @MainActor (Bool) async -> Void = { _ in }
    ) {
        self.repository = repository
        self.searchPageSize = searchPageSize
        self.onMutation = onMutation
    }

    var pinnedFriends: [DashboardFriendDetailDTO] {
        let pinned = friends.filter { $0.pinOrder != nil }
        if let pinnedOrderIDs {
            let positions = Dictionary(uniqueKeysWithValues: pinnedOrderIDs.enumerated().map { ($1, $0) })
            return pinned.sorted {
                positions[$0.member.id ?? -1, default: .max] < positions[$1.member.id ?? -1, default: .max]
            }
        }
        return pinned.sorted { ($0.pinOrder ?? .max) < ($1.pinOrder ?? .max) }
    }

    var unpinnedFriends: [DashboardFriendDetailDTO] {
        friends.filter { $0.pinOrder == nil }
    }

    var hasPendingRequests: Bool {
        !receivedRequests.isEmpty || !sentRequests.isEmpty
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await reload()
        } catch {
            errorKey = "social.error.load"
        }
    }

    func refresh() async {
        do {
            try await reload()
        } catch {
            errorKey = "social.error.load"
        }
    }

    func search(keyword: String, page: Int = 0) async {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            clearSearch()
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let result = try await repository.search(
                keyword: keyword,
                page: max(0, page),
                size: searchPageSize
            )
            searchResults = result.content
            searchPage = result.number
            searchTotalPages = result.totalPages
            searchTotalElements = result.totalElements
        } catch {
            searchResults = []
            errorKey = "social.error.search"
        }
    }

    func clearSearch() {
        searchResults = []
        searchPage = 0
        searchTotalPages = 0
        searchTotalElements = 0
    }

    func sendFriendRequest(to member: MemberPreviewDTO) async {
        guard let id = member.id else { return }
        await perform(error: "social.error.sendFriend", affectsReceivedRequestCount: false) {
            try await repository.sendFriendRequest(to: id)
            try await reload()
            searchResults.removeAll { $0.id == id }
        }
    }

    func accept(_ request: FriendRequestDTO) async {
        guard let id = request.fromMember.id else { return }
        await perform(error: "social.error.accept", affectsReceivedRequestCount: true) {
            try await repository.acceptRequest(from: id)
            try await reload()
        }
    }

    func reject(_ request: FriendRequestDTO) async {
        guard let id = request.fromMember.id else { return }
        await perform(error: "social.error.reject", affectsReceivedRequestCount: true) {
            try await repository.rejectRequest(from: id)
            try await reload()
        }
    }

    func cancel(_ request: FriendRequestDTO) async {
        guard let id = request.toMember.id else { return }
        await perform(error: "social.error.cancel", affectsReceivedRequestCount: false) {
            try await repository.cancelRequest(to: id)
            try await reload()
        }
    }

    func sendFamilyRequest(to friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        guard !sentRequests.contains(where: { $0.toMember.id == id }) else {
            errorKey = "social.error.familyAlreadyRequested"
            return
        }
        await perform(error: "social.error.sendFamily", affectsReceivedRequestCount: false) {
            try await repository.sendFamilyRequest(to: id)
            try await reload()
        }
    }

    func removeFromFamily(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        await perform(error: "social.error.removeFamily", affectsReceivedRequestCount: false) {
            try await repository.removeFromFamily(id)
            try await reload()
        }
    }

    func removeFriend(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        await perform(error: "social.error.removeFriend", affectsReceivedRequestCount: false) {
            try await repository.removeFriend(id)
            try await reload()
        }
    }

    func togglePin(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        await perform(
            error: friend.pinOrder == nil ? "social.error.pin" : "social.error.unpin",
            affectsReceivedRequestCount: false
        ) {
            if friend.pinOrder == nil {
                try await repository.pin(id)
            } else {
                try await repository.unpin(id)
            }
            try await reload()
        }
    }

    func movePinned(fromOffsets: IndexSet, toOffset: Int) async {
        var ids = pinnedFriends.compactMap(\.member.id)
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        pinnedOrderIDs = ids
        do {
            try await repository.updatePinnedOrder(ids)
            try await reload()
            await onMutation(false)
        } catch {
            pinnedOrderIDs = nil
            errorKey = "social.error.reorder"
        }
    }

    func dismissError() {
        errorKey = nil
    }

    private func reload() async throws {
        let info = try await repository.friendInfo()
        friends = info.friends
        receivedRequests = info.pendingRequestsTo
        sentRequests = info.pendingRequestsFrom
        pinnedOrderIDs = nil
    }

    private func perform(
        error errorKey: String,
        affectsReceivedRequestCount: Bool,
        operation: () async throws -> Void
    ) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await operation()
            await onMutation(affectsReceivedRequestCount)
        } catch {
            self.errorKey = errorKey
        }
    }
}
