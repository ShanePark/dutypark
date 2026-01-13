import Foundation

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var receivedRequests: [DashboardFriendRequestDto] = []
    @Published var sentRequests: [DashboardFriendRequestDto] = []
    @Published var isLoading = false
    @Published var searchResults: [SimpleMemberDto] = []
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var error: String?

    func loadFriends() async {
        isLoading = true
        error = nil

        do {
            // Load friends list
            let friendsResponse: [Friend] = try await APIClient.shared.request(.friends, responseType: [Friend].self)
            friends = friendsResponse

            // Load friend requests from dashboard
            let dashboardInfo: DashboardFriendInfo = try await APIClient.shared.request(.friendsDashboard, responseType: DashboardFriendInfo.self)
            receivedRequests = dashboardInfo.pendingRequestsFrom
            sentRequests = dashboardInfo.pendingRequestsTo
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func searchFriends() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            let response: PageResponse<SimpleMemberDto> = try await APIClient.shared.request(
                .searchFriends(keyword: searchQuery),
                responseType: PageResponse<SimpleMemberDto>.self
            )
            searchResults = response.content
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func sendFriendRequest(to memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.sendFriendRequest(toMemberId: memberId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func cancelFriendRequest(to memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.cancelFriendRequest(toMemberId: memberId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func acceptFriendRequest(from memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.acceptFriendRequest(fromMemberId: memberId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func rejectFriendRequest(from memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.rejectFriendRequest(fromMemberId: memberId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func upgradeToFamily(_ friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.upgradeToFamily(friendId: friendId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func demoteFromFamily(_ friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.demoteFromFamily(friendId: friendId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unfriend(_ memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.unfriend(memberId: memberId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func pinFriend(_ friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.pinFriend(friendId: friendId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unpinFriend(_ friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.unpinFriend(friendId: friendId))
            await loadFriends()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
