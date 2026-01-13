import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var myDetail: DashboardMyDetail?
    @Published var friendInfo: DashboardFriendInfo?
    @Published var isLoading = false
    @Published var error: String?

    var allFriends: [DashboardFriendDetail] {
        friendInfo?.friends.sorted { friend1, friend2 in
            // Pinned friends first, sorted by pinOrder
            if let pin1 = friend1.pinOrder, let pin2 = friend2.pinOrder {
                return pin1 < pin2
            } else if friend1.pinOrder != nil {
                return true
            } else if friend2.pinOrder != nil {
                return false
            }
            // Then by name
            return friend1.member.name < friend2.member.name
        } ?? []
    }

    var pinnedFriends: [DashboardFriendDetail] {
        friendInfo?.friends.filter { $0.pinOrder != nil }.sorted { ($0.pinOrder ?? 0) < ($1.pinOrder ?? 0) } ?? []
    }

    var receivedRequests: [DashboardFriendRequestDto] {
        friendInfo?.pendingRequestsFrom ?? []
    }

    var sentRequests: [DashboardFriendRequestDto] {
        friendInfo?.pendingRequestsTo ?? []
    }

    func pinFriend(memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.pinFriend(friendId: memberId))
            await loadDashboard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unpinFriend(memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.unpinFriend(friendId: memberId))
            await loadDashboard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        do {
            async let myDetailTask = APIClient.shared.request(
                .dashboard,
                responseType: DashboardMyDetail.self
            )
            async let friendInfoTask = APIClient.shared.request(
                .friendsDashboard,
                responseType: DashboardFriendInfo.self
            )

            myDetail = try await myDetailTask
            friendInfo = try await friendInfoTask
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func acceptFriendRequest(fromMemberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.acceptFriendRequest(fromMemberId: fromMemberId))
            await loadDashboard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func rejectFriendRequest(fromMemberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.rejectFriendRequest(fromMemberId: fromMemberId))
            await loadDashboard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func cancelFriendRequest(toMemberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.cancelFriendRequest(toMemberId: toMemberId))
            await loadDashboard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
