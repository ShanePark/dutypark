import Combine
import Foundation

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var friends: [DashboardFriendDetailDTO] = []
    @Published private(set) var receivedRequests: [FriendRequestDTO] = []
    @Published private(set) var sentRequests: [FriendRequestDTO] = []
    @Published private(set) var searchResults: [MemberPreviewDTO] = []
    @Published private(set) var blockedMembers: [BlockedMemberDTO] = []
    @Published private(set) var searchPage = 0
    @Published private(set) var searchTotalPages = 0
    @Published private(set) var searchTotalElements: Int64 = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published private(set) var isPerformingAction = false
    @Published private(set) var isReordering = false
    @Published var errorKey: String?
#if DEBUG
    @Published private(set) var uiTestingPinnedOrderSaveCount = 0
#endif

    private let repository: any SocialRepository
    private let searchPageSize: Int
    private let onMutation: @MainActor (Bool) async -> Void
    private let haptics: DPHapticCenter
    private var pinnedOrderIDs: [MemberID]?

    init(
        repository: any SocialRepository = LiveSocialRepository(),
        searchPageSize: Int = 5,
        onMutation: @escaping @MainActor (Bool) async -> Void = { _ in },
        haptics: DPHapticCenter = .shared
    ) {
        self.repository = repository
        self.searchPageSize = searchPageSize
        self.onMutation = onMutation
        self.haptics = haptics
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
#if DEBUG
        if isUITesting {
            loadUITestingFixture()
            return
        }
#endif
        isLoading = true
        defer { isLoading = false }
        do {
            try await reload()
        } catch {
            errorKey = "social.error.load"
        }
    }

    func refresh() async {
#if DEBUG
        if isUITesting {
            loadUITestingFixture()
            return
        }
#endif
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
            let previousPage = searchPage
            let result = try await repository.search(
                keyword: keyword,
                page: max(0, page),
                size: searchPageSize
            )
            searchResults = result.content
            searchPage = result.number
            searchTotalPages = result.totalPages
            searchTotalElements = result.totalElements
            if result.number != previousPage {
                haptics.emit(.selection)
            }
        } catch {
            searchResults = []
            errorKey = "social.error.search"
            haptics.emit(.error)
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
        await perform(
            error: "social.error.sendFriend",
            affectsReceivedRequestCount: false,
            reconcileAfterMutation: true,
            optimisticUpdate: { searchResults.removeAll { $0.id == id } }
        ) {
            try await repository.sendFriendRequest(to: id)
        }
    }

    func accept(_ request: FriendRequestDTO) async {
        guard let id = request.fromMember.id else { return }
        await perform(
            error: "social.error.accept",
            affectsReceivedRequestCount: true,
            reconcileAfterMutation: true,
            optimisticUpdate: { receivedRequests.removeAll { $0.id == request.id } }
        ) {
            try await repository.acceptRequest(from: id)
        }
    }

    func reject(_ request: FriendRequestDTO) async {
        guard let id = request.fromMember.id else { return }
        await perform(
            error: "social.error.reject",
            affectsReceivedRequestCount: true,
            optimisticUpdate: { receivedRequests.removeAll { $0.id == request.id } }
        ) {
            try await repository.rejectRequest(from: id)
        }
    }

    func cancel(_ request: FriendRequestDTO) async {
        guard let id = request.toMember.id else { return }
        await perform(
            error: "social.error.cancel",
            affectsReceivedRequestCount: false,
            optimisticUpdate: { sentRequests.removeAll { $0.id == request.id } }
        ) {
            try await repository.cancelRequest(to: id)
        }
    }

    func sendFamilyRequest(to friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        guard !sentRequests.contains(where: { $0.toMember.id == id }) else {
            errorKey = "social.error.familyAlreadyRequested"
            haptics.emit(.warning)
            return
        }
        await perform(
            error: "social.error.sendFamily",
            affectsReceivedRequestCount: false,
            reconcileAfterMutation: true
        ) {
            try await repository.sendFamilyRequest(to: id)
        }
    }

    func removeFromFamily(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        await perform(
            error: "social.error.removeFamily",
            affectsReceivedRequestCount: false,
            optimisticUpdate: { replaceFriend(id: id) { $0.replacingFamily(false) } }
        ) {
            try await repository.removeFromFamily(id)
        }
    }

    func removeFriend(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        await perform(
            error: "social.error.removeFriend",
            affectsReceivedRequestCount: false,
            optimisticUpdate: { friends.removeAll { $0.member.id == id } }
        ) {
            try await repository.removeFriend(id)
        }
    }

    /// Blocking unfriends both directions on the server, so the confirmed
    /// mutation is reconciled instead of patched locally.
    func block(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
        let affectsReceivedRequestCount = receivedRequests.contains {
            $0.fromMember.id == id
        }
        await perform(
            error: "social.error.block",
            affectsReceivedRequestCount: affectsReceivedRequestCount,
            reconcileAfterMutation: true,
            optimisticUpdate: { friends.removeAll { $0.member.id == id } }
        ) {
            try await repository.block(id)
        }
    }

    func unblock(_ member: BlockedMemberDTO) async {
        await perform(
            error: "social.error.unblock",
            affectsReceivedRequestCount: false,
            optimisticUpdate: { blockedMembers.removeAll { $0.id == member.id } }
        ) {
            try await repository.unblock(member.id)
        }
    }

    func togglePin(_ friend: DashboardFriendDetailDTO) async {
        guard let id = friend.member.id else { return }
#if DEBUG
        if isSocialReorderUITesting {
            let pinOrder = friend.pinOrder == nil ? nextPinOrder : nil
            replaceFriend(id: id) { $0.replacingPinOrder(pinOrder) }
            await onMutation(false)
            return
        }
#endif
        await perform(
            error: friend.pinOrder == nil ? "social.error.pin" : "social.error.unpin",
            affectsReceivedRequestCount: false,
            optimisticUpdate: {
                let pinOrder = friend.pinOrder == nil ? nextPinOrder : nil
                replaceFriend(id: id) { $0.replacingPinOrder(pinOrder) }
            }
        ) {
            if friend.pinOrder == nil {
                try await repository.pin(id)
            } else {
                try await repository.unpin(id)
            }
        }
    }

    @discardableResult
    func savePinnedOrder(_ memberIDs: [MemberID]) async -> Bool {
        guard !isReordering else { return false }
        let currentIDs = pinnedFriends.compactMap(\.member.id)
        guard memberIDs.count == currentIDs.count,
              Set(memberIDs) == Set(currentIDs) else {
            errorKey = "social.error.reorder"
            haptics.emit(.error)
            return false
        }
        guard memberIDs != currentIDs else { return true }

#if DEBUG
        if isUITesting {
            pinnedOrderIDs = memberIDs
            if isSocialReorderUITesting {
                uiTestingPinnedOrderSaveCount += 1
            }
            await onMutation(false)
            return true
        }
#endif

        let previousOrderIDs = pinnedOrderIDs
        pinnedOrderIDs = memberIDs
        isReordering = true
        defer { isReordering = false }

        do {
            try await repository.updatePinnedOrder(memberIDs)
        } catch {
            pinnedOrderIDs = previousOrderIDs
            errorKey = "social.error.reorder"
            haptics.emit(.error)
            return false
        }

        applyPinnedOrder(memberIDs)
        pinnedOrderIDs = nil
        errorKey = nil
        haptics.emit(.success)

        await onMutation(false)
        return true
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
        blockedMembers = try await repository.blockedMembers()
    }

    private func perform(
        error errorKey: String,
        affectsReceivedRequestCount: Bool,
        reconcileAfterMutation: Bool = false,
        optimisticUpdate: () -> Void = {},
        operation: () async throws -> Void
    ) async {
        guard !isPerformingAction else { return }
        let snapshot = mutationSnapshot
        isPerformingAction = true
        defer { isPerformingAction = false }
        optimisticUpdate()
        do {
            try await operation()
        } catch {
            restore(snapshot)
            self.errorKey = errorKey
            haptics.emit(.error)
            return
        }
        self.errorKey = nil
        // Emit immediately after the server confirms the mutation. Reloading the
        // dashboard below is reconciliation, not part of the mutation result, so
        // a transient refresh failure must not turn a completed action into an
        // error haptic.
        haptics.emit(.success)
        if reconcileAfterMutation {
            // The mutation is already confirmed. A transient reconciliation
            // failure must not roll it back or be reported as an action failure.
            try? await reload()
        }
        await onMutation(affectsReceivedRequestCount)
    }

    private var nextPinOrder: Int64 {
        (friends.compactMap(\.pinOrder).max() ?? -1) + 1
    }

    private func replaceFriend(
        id: MemberID,
        transform: (DashboardFriendDetailDTO) -> DashboardFriendDetailDTO
    ) {
        friends = friends.map { friend in
            friend.member.id == id ? transform(friend) : friend
        }
    }

    private func applyPinnedOrder(_ memberIDs: [MemberID]) {
        let orders = Dictionary(
            uniqueKeysWithValues: memberIDs.enumerated().map { ($1, Int64($0)) }
        )
        friends = friends.map { friend in
            guard let memberID = friend.member.id,
                  let pinOrder = orders[memberID] else { return friend }
            return friend.replacingPinOrder(pinOrder)
        }
    }

    private var mutationSnapshot: MutationSnapshot {
        MutationSnapshot(
            friends: friends,
            receivedRequests: receivedRequests,
            sentRequests: sentRequests,
            searchResults: searchResults,
            blockedMembers: blockedMembers,
            pinnedOrderIDs: pinnedOrderIDs
        )
    }

    private func restore(_ snapshot: MutationSnapshot) {
        friends = snapshot.friends
        receivedRequests = snapshot.receivedRequests
        sentRequests = snapshot.sentRequests
        searchResults = snapshot.searchResults
        blockedMembers = snapshot.blockedMembers
        pinnedOrderIDs = snapshot.pinnedOrderIDs
    }

    private struct MutationSnapshot {
        let friends: [DashboardFriendDetailDTO]
        let receivedRequests: [FriendRequestDTO]
        let sentRequests: [FriendRequestDTO]
        let searchResults: [MemberPreviewDTO]
        let blockedMembers: [BlockedMemberDTO]
        let pinnedOrderIDs: [MemberID]?
    }

#if DEBUG
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated")
    }

    private var isSocialReorderUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-social-reorder")
            || isSocialReorderOverflowUITesting
    }

    /// Well past the ~6 pinned cards an iPhone 16 Pro viewport shows at once.
    static let uiTestingOverflowPinnedCount = 18

    /// Seeds more pinned friends than fit on screen so the `LazyVStack` stops
    /// publishing drop-target frames for the rows outside the viewport.
    private var isSocialReorderOverflowUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-social-reorder-overflow")
    }

    private func loadUITestingFixture() {
        if isSocialReorderOverflowUITesting {
            var overflowFriends: [DashboardFriendDetailDTO] = []
            for index in 0..<SocialViewModel.uiTestingOverflowPinnedCount {
                let id = MemberID(41 + index)
                overflowFriends.append(
                    uiTestingFriend(id: id, name: "핀친구 \(index + 1)", pinOrder: Int64(index + 1))
                )
            }
            friends = overflowFriends
        } else if isSocialReorderUITesting {
            friends = [
                uiTestingFriend(id: 31, name: "알렉스", pinOrder: 1),
                uiTestingFriend(id: 32, name: "민지", pinOrder: 2),
                uiTestingFriend(id: 33, name: "테일러", pinOrder: 3),
                uiTestingFriend(id: 34, name: "지우", pinOrder: 4),
                uiTestingFriend(id: 35, name: "하늘", pinOrder: 5),
                uiTestingFriend(id: 36, name: "유진", pinOrder: 6)
            ]
        } else {
            friends = [
                uiTestingFriend(id: 31, name: "알렉스", pinOrder: 1),
                uiTestingFriend(id: 32, name: "민지", pinOrder: 2),
                uiTestingFriend(id: 33, name: "테일러", pinOrder: nil)
            ]
        }
        receivedRequests = []
        sentRequests = []
        blockedMembers = []
        pinnedOrderIDs = nil
        errorKey = nil
        uiTestingPinnedOrderSaveCount = 0
    }

    private func uiTestingFriend(
        id: MemberID,
        name: String,
        pinOrder: Int64?
    ) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: MemberPreviewDTO(
                id: id,
                name: name,
                teamId: 1,
                team: "Dutypark",
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            ),
            duty: nil,
            schedules: [],
            isFamily: false,
            pinOrder: pinOrder
        )
    }
#endif
}

private extension DashboardFriendDetailDTO {
    func replacingFamily(_ isFamily: Bool) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: member,
            duty: duty,
            schedules: schedules,
            isFamily: isFamily,
            pinOrder: pinOrder
        )
    }

    func replacingPinOrder(_ pinOrder: Int64?) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: member,
            duty: duty,
            schedules: schedules,
            isFamily: isFamily,
            pinOrder: pinOrder
        )
    }
}
