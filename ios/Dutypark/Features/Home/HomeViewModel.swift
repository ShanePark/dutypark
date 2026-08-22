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
    private var myRequestRevision = 0
    private var friendsRequestRevision = 0

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
        let previousMyDashboard = myDashboard
        let previousFriendsDashboard = friendsDashboard
        if previousMyDashboard == nil {
            myState = .loading
        }
        if previousFriendsDashboard == nil {
            friendsState = .loading
        }
        myRequestRevision += 1
        friendsRequestRevision += 1
        let myRevision = myRequestRevision
        let friendsRevision = friendsRequestRevision

        async let myResult = Self.fetchMy(using: service)
        async let friendsResult = Self.fetchFriends(using: service)
        let (my, friends) = await (myResult, friendsResult)

        if myRevision == myRequestRevision {
            myState = switch my {
            case .success(let dashboard): .loaded(dashboard)
            case .failure:
                if let previousMyDashboard { .loaded(previousMyDashboard) } else { .failed }
            }
        }
        if friendsRevision == friendsRequestRevision {
            friendsState = switch friends {
            case .success(let dashboard): .loaded(dashboard)
            case .failure:
                if let previousFriendsDashboard { .loaded(previousFriendsDashboard) } else { .failed }
            }
        }
    }

    func retryMyDashboard() async {
        let previousDashboard = myDashboard
        if previousDashboard == nil {
            myState = .loading
        }
        myRequestRevision += 1
        let revision = myRequestRevision
        let result = await Self.fetchMy(using: service)
        if revision == myRequestRevision {
            myState = switch result {
            case .success(let dashboard): .loaded(dashboard)
            case .failure:
                if let previousDashboard { .loaded(previousDashboard) } else { .failed }
            }
        }
    }

    func retryFriendsDashboard() async {
        let previousDashboard = friendsDashboard
        if previousDashboard == nil {
            friendsState = .loading
        }
        friendsRequestRevision += 1
        let revision = friendsRequestRevision
        let result = await Self.fetchFriends(using: service)
        if revision == friendsRequestRevision {
            friendsState = switch result {
            case .success(let dashboard): .loaded(dashboard)
            case .failure:
                if let previousDashboard { .loaded(previousDashboard) } else { .failed }
            }
        }
    }

    func replaceFriendsDashboardForMutation(_ dashboard: DashboardFriendInfoDTO?) {
        guard let dashboard else { return }
        friendsRequestRevision += 1
        friendsState = .loaded(dashboard)
    }

    func setFriendPinned(memberID: MemberID, isPinned: Bool) {
        guard let dashboard = friendsDashboard else { return }
        let nextPinOrder = isPinned
            ? (dashboard.friends.compactMap(\.pinOrder).max() ?? -1) + 1
            : nil
        let updatedFriends = dashboard.friends.map { friend in
            guard friend.member.id == memberID else { return friend }
            return friend.replacingPinOrder(nextPinOrder)
        }
        replaceFriendsDashboardForMutation(dashboard.replacingFriends(updatedFriends))
    }

    func setPinnedFriendOrder(_ memberIDs: [MemberID]) {
        guard let dashboard = friendsDashboard else { return }
        let currentIDs = dashboard.friends.compactMap { friend in
            friend.pinOrder == nil ? nil : friend.member.id
        }
        guard memberIDs.count == currentIDs.count,
              Set(memberIDs) == Set(currentIDs) else { return }

        let orders = Dictionary(
            uniqueKeysWithValues: memberIDs.enumerated().map { ($1, Int64($0)) }
        )
        let updatedFriends = dashboard.friends.map { friend in
            guard let memberID = friend.member.id,
                  let pinOrder = orders[memberID] else { return friend }
            return friend.replacingPinOrder(pinOrder)
        }
        replaceFriendsDashboardForMutation(dashboard.replacingFriends(updatedFriends))
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
            appleId: nil,
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        myState = .loaded(DashboardMyDetailDTO(member: member, duty: nil, schedules: []))
        // The many-pinned fixture spans every card variant — team or not, duty or
        // not, off duty, and a team name long enough to need shrinking — so a UI
        // test can prove none of them changes the card's size.
        let friends = if ProcessInfo.processInfo.arguments.contains("-ui-testing-home-many-pinned") {
            [
                uiTestingFriend(id: 31, name: "첫째 친구", team: "간호1팀", duty: uiTestingDuty("주간"), pinOrder: 0),
                uiTestingFriend(id: 32, name: "둘째 친구", duty: uiTestingDuty("야간"), pinOrder: 1),
                uiTestingFriend(id: 33, name: "셋째 친구", team: "간호2팀", pinOrder: 2),
                uiTestingFriend(id: 34, name: "넷째 친구", pinOrder: 3),
                uiTestingFriend(
                    id: 35,
                    name: "다섯째 친구",
                    team: "아주 긴 이름의 병동 간호팀",
                    duty: uiTestingDuty("주간"),
                    pinOrder: 4
                ),
                uiTestingFriend(id: 36, name: "여섯째 친구", duty: uiTestingDuty(nil), pinOrder: 5),
            ]
        } else {
            [
                uiTestingFriend(id: 21, name: "김간호", team: "간호1팀", duty: uiTestingDuty("주간"), pinOrder: 0),
                uiTestingFriend(id: 22, name: "박야간", duty: uiTestingDuty("야간"), pinOrder: 1),
                uiTestingFriend(id: 23, name: "이휴무", team: "응급팀", duty: uiTestingDuty(nil), pinOrder: nil),
            ]
        }
        friendsState = .loaded(DashboardFriendInfoDTO(
            friends: friends,
            pendingRequestsTo: [],
            pendingRequestsFrom: []
        ))
    }

    private func uiTestingFriend(
        id: MemberID,
        name: String,
        team: String? = nil,
        duty: DutyDTO? = nil,
        pinOrder: Int64?
    ) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: MemberPreviewDTO(
                id: id,
                name: name,
                teamId: team == nil ? nil : 7,
                team: team,
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            ),
            duty: duty,
            schedules: [],
            isFamily: id == 21,
            pinOrder: pinOrder
        )
    }

    private func uiTestingDuty(_ dutyType: String?) -> DutyDTO {
        DutyDTO(
            year: 2026,
            month: 8,
            day: 15,
            dutyType: dutyType,
            dutyColor: dutyType == nil ? nil : "#2563EB",
            isOff: dutyType == nil,
            dutyTypeId: nil,
            source: .pattern
        )
    }
#endif
}

private extension DashboardFriendDetailDTO {
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

private extension DashboardFriendInfoDTO {
    func replacingFriends(_ friends: [DashboardFriendDetailDTO]) -> DashboardFriendInfoDTO {
        DashboardFriendInfoDTO(
            friends: friends,
            pendingRequestsTo: pendingRequestsTo,
            pendingRequestsFrom: pendingRequestsFrom
        )
    }
}

private nonisolated enum DashboardResult<Value: Sendable>: Sendable {
    case success(Value)
    case failure
}
