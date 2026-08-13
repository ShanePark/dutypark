import Foundation
import Combine

nonisolated enum HomeRoute: Equatable, Sendable {
    case memberCalendar(MemberID)
    case friends
}

@MainActor
final class HomeViewModel: ObservableObject {
    enum LoadState<Value> {
        case idle
        case loading
        case loaded(Value)
        case failed
    }

    @Published private(set) var myState: LoadState<DashboardMyDetailDTO> = .idle
    @Published private(set) var friendsState: LoadState<DashboardFriendInfoDTO> = .idle

    private let service: any HomeDashboardServing

    init(service: any HomeDashboardServing) {
        self.service = service
    }

    var myDashboard: DashboardMyDetailDTO? {
        guard case .loaded(let dashboard) = myState else { return nil }
        return dashboard
    }

    var friendsDashboard: DashboardFriendInfoDTO? {
        guard case .loaded(let dashboard) = friendsState else { return nil }
        return dashboard
    }

    var sortedFriends: [DashboardFriendDetailDTO] {
        guard let friends = friendsDashboard?.friends else { return [] }
        return friends.enumerated().sorted { first, second in
            switch (first.element.pinOrder, second.element.pinOrder) {
            case let (firstOrder?, secondOrder?):
                return firstOrder == secondOrder ? first.offset < second.offset : firstOrder < secondOrder
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return first.offset < second.offset
            }
        }.map(\.element)
    }

    var receivedRequestCount: Int {
        friendsDashboard?.pendingRequestsTo.count ?? 0
    }

    var sentRequestCount: Int {
        friendsDashboard?.pendingRequestsFrom.count ?? 0
    }

    func loadIfNeeded() async {
        guard case .idle = myState, case .idle = friendsState else { return }
        await refresh()
    }

    func refresh() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        myState = .loading
        friendsState = .loading

        async let myResult = Self.fetchMy(using: service)
        async let friendsResult = Self.fetchFriends(using: service)
        let (my, friends) = await (myResult, friendsResult)

        myState = switch my {
        case .success(let dashboard): .loaded(dashboard)
        case .failure: .failed
        }
        friendsState = switch friends {
        case .success(let dashboard): .loaded(dashboard)
        case .failure: .failed
        }
    }

    func retryMyDashboard() async {
        myState = .loading
        myState = switch await Self.fetchMy(using: service) {
        case .success(let dashboard): .loaded(dashboard)
        case .failure: .failed
        }
    }

    func retryFriendsDashboard() async {
        friendsState = .loading
        friendsState = switch await Self.fetchFriends(using: service) {
        case .success(let dashboard): .loaded(dashboard)
        case .failure: .failed
        }
    }

    private nonisolated static func fetchMy(
        using service: any HomeDashboardServing
    ) async -> DashboardResult<DashboardMyDetailDTO> {
        do {
            return .success(try await service.loadMyDashboard())
        } catch {
            return .failure
        }
    }

    private nonisolated static func fetchFriends(
        using service: any HomeDashboardServing
    ) async -> DashboardResult<DashboardFriendInfoDTO> {
        do {
            return .success(try await service.loadFriendsDashboard())
        } catch {
            return .failure
        }
    }

#if DEBUG
    private func loadUITestingFixture() {
        let member = MemberDTO(
            id: 1,
            name: "UI Test",
            email: nil,
            teamId: nil,
            team: nil,
            calendarVisibility: .friends,
            kakaoId: nil,
            naverId: nil,
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        myState = .loaded(DashboardMyDetailDTO(member: member, duty: nil, schedules: []))
        friendsState = .loaded(DashboardFriendInfoDTO(
            friends: [],
            pendingRequestsTo: [],
            pendingRequestsFrom: []
        ))
    }
#endif
}

private nonisolated enum DashboardResult<Value: Sendable>: Sendable {
    case success(Value)
    case failure
}
