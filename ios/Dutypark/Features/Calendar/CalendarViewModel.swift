import Foundation
import Combine

nonisolated struct CalendarDayContent: Identifiable, Equatable, Sendable {
    let cell: CalendarCell
    let duty: DutyDTO?
    let schedules: [ScheduleDTO]
    let holidays: [HolidayDTO]
    let todos: [TodoDTO]
    let dDays: [DDayDTO]
    let comparedDuties: [ComparedDuty]

    var id: String { cell.id }
}

nonisolated struct ComparedDuty: Equatable, Sendable {
    let memberID: MemberID
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let duty: DutyDTO
}

/// Semantic feedback decisions owned by the calendar state boundary.
///
/// The calendar has several ways to reach the same month (buttons, a swipe and the picker),
/// so the view model keeps the committed month transition in one place. The optional result
/// also makes no-op transitions naturally silent.
nonisolated enum CalendarHapticPolicy {
    static func monthNavigation(
        fromYear: Int,
        fromMonth: Int,
        toYear: Int,
        toMonth: Int
    ) -> DPHapticKind? {
        fromYear == toYear && fromMonth == toMonth ? nil : .routine
    }

    static func selectionChanged(from: DateOnly?, to: DateOnly?) -> DPHapticKind? {
        from == to ? nil : .selection
    }

    static func mutationResult(succeeded: Bool) -> DPHapticKind {
        succeeded ? .success : .error
    }

    static func validationFailure(isActionable: Bool = true) -> DPHapticKind? {
        isActionable ? .warning : nil
    }
}

/// A short, bounded recovery window handles the case where the path monitor
/// stays satisfied while the API server is restarting. The retry is deliberately
/// feature-local and haptic-free; the shared outbox coordinator owns durable
/// queue retries separately.
nonisolated enum CalendarServerRecoveryPolicy {
    static let delays: [TimeInterval] = [5, 10, 20]

    static func delay(forAttempt attempt: Int) -> TimeInterval? {
        guard delays.indices.contains(attempt) else { return nil }
        return delays[attempt]
    }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    private struct MonthRequestContext: Equatable {
        let year: Int
        let month: Int
        let memberID: MemberID
        let accountID: MemberID?
        let isMine: Bool
        let comparedMemberIDs: Set<MemberID>
        let generation: Int
    }

    private let repository: CalendarRepositoryProtocol
    private let cache: any OfflineCacheProviding
    private let outbox: any OfflineOutboxProviding
    private var initialAccountID: MemberID?
    private var monthLoadGeneration = 0
    private var prefersOfflineCache: Bool
    private var prefetchTask: Task<Void, Never>?
    private var serverRecoveryTask: Task<Void, Never>?
    private var serverRecoveryPending = false
    private var serverRecoveryNeedsIdentity = false
    private var serverRecoveryAttemptInProgress = false
    private let serverRecoverySleeper: @Sendable (TimeInterval) async throws -> Void
    private let requestOfflineSync: @MainActor @Sendable (MemberID) async -> Void
    @Published private(set) var me: MemberDTO?
    @Published private(set) var targetMember: MemberPreviewDTO?
    @Published private(set) var friends: [FriendDTO] = []
    @Published private(set) var team: TeamDTO?
    @Published private(set) var days: [CalendarDayContent] = []
    @Published private(set) var dDays: [DDayDTO] = []
    @Published private(set) var todoBoard: TodoBoardDTO?
    @Published private(set) var canManage = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var searchResults: [ScheduleSearchResultDTO] = []

    @Published var year: Int
    @Published var month: Int
    @Published var selectedMemberID: MemberID?
    @Published var selectedDay: CalendarDayContent?
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var highlightedDate: DateOnly?
    @Published var comparedMemberIDs: Set<MemberID> = []
    @Published var isQuickDutyEditing = false
    @Published private(set) var quickDutyDay: CalendarDayContent?
    @Published private(set) var canLoadMoreSearchResults = false
    @Published private(set) var pinnedDDayID: Int64?
    @Published private(set) var isShowingCachedData = false
    @Published private(set) var cacheStoredAt: Date?
    @Published private(set) var isOfflineMode = false
    @Published private(set) var pendingScheduleCount = 0
    @Published var dutyBatchMessage: String?
    private var searchPage = 0
    private let initialScheduleID: ScheduleID?
    private let contentFilter: ContentFilterStore
    private let hapticCenter: DPHapticCenter

    init(
        repository: CalendarRepositoryProtocol = CalendarRepository(),
        now: Date = Date(),
        memberID: MemberID? = nil,
        accountID: MemberID? = nil,
        isOffline: Bool = false,
        date: DateOnly? = nil,
        scheduleID: ScheduleID? = nil,
        contentFilter: ContentFilterStore = .shared,
        hapticCenter: DPHapticCenter = .shared,
        cache: any OfflineCacheProviding = OfflineCacheStore.shared,
        outbox: any OfflineOutboxProviding = OfflineOutboxStore.shared,
        serverRecoverySleeper: @escaping @Sendable (TimeInterval) async throws -> Void = { delay in
            try await Task.sleep(for: .seconds(delay))
        },
        requestOfflineSync: @escaping @MainActor @Sendable (MemberID) async -> Void = { accountID in
            await OfflineSyncCoordinator.shared.synchronize(
                accountID: accountID,
                networkStatus: .satisfied
            )
        }
    ) {
        self.repository = repository
        self.cache = cache
        self.outbox = outbox
        initialAccountID = accountID
        prefersOfflineCache = isOffline
        isOfflineMode = isOffline
        self.contentFilter = contentFilter
        self.hapticCenter = hapticCenter
        self.serverRecoverySleeper = serverRecoverySleeper
        self.requestOfflineSync = requestOfflineSync
        initialScheduleID = scheduleID
        let initialDate = date.flatMap(CalendarDateSupport.date(from:)) ?? now
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: initialDate)
        year = parts.year ?? 2026
        month = parts.month ?? 1
        selectedMemberID = memberID
        highlightedDate = date
    }

    deinit {
        prefetchTask?.cancel()
        serverRecoveryTask?.cancel()
    }

    var targetMemberID: MemberID? { selectedMemberID ?? me?.id }
    var isMyCalendar: Bool { targetMemberID == me?.id }
    var canEdit: Bool { isMyCalendar || canManage }
    var canSearchSchedules: Bool { canEdit }
    var targetName: String {
        guard let targetMemberID else { return me?.name ?? "" }
        if targetMemberID == me?.id { return me?.name ?? "" }
        return friends.first(where: { $0.id == targetMemberID })?.name ?? targetMember?.name ?? ""
    }
    var targetHasProfilePhoto: Bool {
        guard let targetMemberID else { return me?.hasProfilePhoto ?? false }
        if targetMemberID == me?.id { return me?.hasProfilePhoto ?? false }
        return friends.first(where: { $0.id == targetMemberID })?.hasProfilePhoto
            ?? targetMember?.hasProfilePhoto
            ?? false
    }
    var targetProfilePhotoVersion: Int64 {
        guard let targetMemberID else { return me?.profilePhotoVersion ?? 0 }
        if targetMemberID == me?.id { return me?.profilePhotoVersion ?? 0 }
        return friends.first(where: { $0.id == targetMemberID })?.profilePhotoVersion
            ?? targetMember?.profilePhotoVersion
            ?? 0
    }
    var visibleDutyTypes: [DutyTypeDTO] { team?.dutyTypes.filter { !$0.hidden } ?? [] }

    func configure(accountID: MemberID, isOffline: Bool) {
        if initialAccountID != accountID || prefersOfflineCache != isOffline {
            monthLoadGeneration += 1
        }
        if initialAccountID != accountID {
            cancelServerRecovery(clearPending: true)
        } else if isOffline {
            cancelServerRecovery(clearPending: false)
        }
        initialAccountID = accountID
        prefersOfflineCache = isOffline
        isOfflineMode = isOffline
    }

    /// Cancels feature-owned background work when the view leaves the hierarchy.
    /// A pending server recovery remains resumable when the same view reappears.
    func cancelBackgroundTasks() {
        prefetchTask?.cancel()
        prefetchTask = nil
        cancelServerRecovery(clearPending: false)
    }

    /// Called from the view's appearance task after a previous disappearance.
    func resumeServerRecoveryIfNeeded() {
        if serverRecoveryPending, !prefersOfflineCache, isOfflineMode {
            scheduleServerRecovery()
        } else if !isOfflineMode {
            startPrefetchIfNeeded()
        }
    }

    /// Called by the app-level outbox coordinator after a successful drain.
    /// Refreshing is deliberately haptic-free because the user did not initiate
    /// this background transition.
    func handleOfflineSyncCompleted() async {
        guard cacheAccountID != nil else { return }
        cancelServerRecovery(clearPending: true)
        // The session may publish the drain notification before its availability
        // observer reaches this view. Clear the cache-only preference first so
        // this reconciliation actually performs the online refresh.
        prefersOfflineCache = false
        isOfflineMode = false
        await load()
    }

    /// Wakes a visible cached calendar as soon as the network path becomes usable.
    /// Session availability can remain online when only a calendar request failed,
    /// so waiting for the session observer would otherwise require a month change.
    func handleNetworkBecameReachable() async {
        guard !prefersOfflineCache,
              isOfflineMode,
              !serverRecoveryAttemptInProgress,
              isMyCalendar,
              let accountID = cacheAccountID
        else { return }

        cancelServerRecovery(clearPending: false)
        serverRecoveryPending = true
        switch await attemptServerRecovery(accountID: accountID) {
        case .recovered, .stop:
            serverRecoveryPending = false
        case .retry:
            scheduleServerRecovery()
        }
    }

    func load(emitErrorFeedback: Bool = false) async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if prefersOfflineCache {
                guard await restoreCachedIdentity() else { throw APIError.transport }
            } else if me == nil {
                do {
                    try await loadOnlineIdentity()
                } catch {
                    guard isRecoverableOfflineError(error), await restoreCachedIdentity() else {
                        throw error
                    }
                    isOfflineMode = true
                    serverRecoveryNeedsIdentity = true
                }
            }
            try await loadMonth()
            if isOfflineMode {
                scheduleServerRecovery()
            }
            pendingScheduleCount = pendingScheduleEntryCount(
                await outbox.entries(accountID: cacheAccountID ?? 0)
            )
            startPrefetchIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.load")
            if emitErrorFeedback { emit(.error) }
        }
    }

    private var cacheAccountID: MemberID? {
        initialAccountID ?? me?.id
    }

    private func beginMonthRequest(memberID: MemberID) -> MonthRequestContext {
        monthLoadGeneration += 1
        return MonthRequestContext(
            year: year,
            month: month,
            memberID: memberID,
            accountID: cacheAccountID,
            isMine: memberID == me?.id,
            comparedMemberIDs: self.comparedMemberIDs,
            generation: monthLoadGeneration
        )
    }

    private func isCurrentMonthRequest(_ context: MonthRequestContext) -> Bool {
        !Task.isCancelled
            && context.generation == monthLoadGeneration
            && context.year == year
            && context.month == month
            && context.memberID == targetMemberID
            && context.accountID == cacheAccountID
            && context.isMine == isMyCalendar
            && context.comparedMemberIDs == comparedMemberIDs
    }

    private func loadOnlineIdentity() async throws {
        let member = try await repository.member()
        me = member
        friends = try await repository.friends()
        if let initialScheduleID {
            let schedule = try await repository.scheduleBasic(id: initialScheduleID)
            if selectedMemberID == nil {
                selectedMemberID = schedule.memberId
            }
            if let date = CalendarDateSupport.date(from: schedule.startDateTime) {
                let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
                year = parts.year ?? year
                month = parts.month ?? month
                highlightedDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", year, month, parts.day ?? 1))
            }
        }
        if selectedMemberID == nil { selectedMemberID = member.id }
        if let selectedMemberID,
           selectedMemberID != member.id,
           !friends.contains(where: { $0.id == selectedMemberID }) {
            targetMember = try await repository.member(id: selectedMemberID)
        }
        let targetTeamID = selectedMemberID == member.id
            ? member.teamId
            : friends.first(where: { $0.id == selectedMemberID })?.teamId ?? targetMember?.teamId
        if let teamID = targetTeamID {
            team = try await repository.team(id: teamID)
        }
        if let member = me, member.id == cacheAccountID {
            try? await cache.saveAccount(OfflineAccountSnapshot(
                member: member,
                friends: friends,
                dDays: dDays,
                storedAt: .now
            ))
        }
    }

    private func restoreCachedIdentity() async -> Bool {
        guard let accountID = cacheAccountID,
              let snapshot = await cache.loadAccount(memberID: accountID)
        else { return false }

        let profile = snapshot.profile
        me = MemberDTO(
            id: profile.memberID,
            name: profile.name,
            email: profile.email,
            teamId: profile.teamID,
            team: profile.teamName,
            calendarVisibility: profile.calendarVisibility,
            kakaoId: nil,
            naverId: nil,
            appleId: nil,
            hasPassword: profile.hasPassword,
            hasProfilePhoto: profile.hasProfilePhoto,
            profilePhotoVersion: profile.profilePhotoVersion
        )
        friends = snapshot.friends
        dDays = snapshot.dDays.sorted { $0.date.rawValue < $1.date.rawValue }
        if selectedMemberID == nil { selectedMemberID = me?.id }
        todoBoard = await cache.loadTodoBoard(accountID: accountID)
        isOfflineMode = true
        return true
    }

    func loadMonth(
        scheduleRecovery: Bool = true,
        forceOnlineRequest: Bool = false
    ) async throws {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let context = beginMonthRequest(memberID: memberID)
        if isOfflineMode, !forceOnlineRequest {
            guard context.isMine, let accountID = context.accountID else {
                throw APIError.transport
            }
            let snapshot = await cache.loadMonth(
                accountID: accountID,
                key: OfflineMonthKey(year: context.year, month: context.month)
            )
            guard isCurrentMonthRequest(context) else { return }
            guard let snapshot else { throw APIError.transport }
            applyCachedMonth(snapshot, context: context)
            await overlayPendingSchedules(for: context)
            guard isCurrentMonthRequest(context) else { return }
            isShowingCachedData = true
            return
        }

        do {
            try await loadMonthFromServer(context: context)
        } catch {
            guard isCurrentMonthRequest(context) else { return }
            guard isRecoverableOfflineError(error),
                  context.isMine,
                  let accountID = context.accountID
            else { throw error }
            let snapshot = await cache.loadMonth(
                accountID: accountID,
                key: OfflineMonthKey(year: context.year, month: context.month)
            )
            guard isCurrentMonthRequest(context) else { return }
            guard let snapshot else { throw error }
            if let accountID = context.accountID {
                if todoBoard == nil {
                    let cachedTodoBoard = await cache.loadTodoBoard(accountID: accountID)
                    guard isCurrentMonthRequest(context) else { return }
                    todoBoard = cachedTodoBoard
                }
                if dDays.isEmpty {
                    let account = await cache.loadAccount(memberID: accountID)
                    guard isCurrentMonthRequest(context) else { return }
                    if let account {
                        dDays = account.dDays.sorted { $0.date.rawValue < $1.date.rawValue }
                    }
                }
            }
            guard isCurrentMonthRequest(context) else { return }
            applyCachedMonth(snapshot, context: context)
            await overlayPendingSchedules(for: context)
            guard isCurrentMonthRequest(context) else { return }
            isOfflineMode = true
            isShowingCachedData = true
            cacheStoredAt = snapshot.storedAt
            if scheduleRecovery {
                scheduleServerRecovery()
                // Let the bounded recovery task enter its first wait before the
                // caller continues. This keeps an injected zero-delay recovery
                // deterministic in tests without blocking the real backoff.
                await Task.yield()
            }
        }
    }

    private func loadMonthFromServer(context: MonthRequestContext) async throws {
        async let calendarResult = repository.calendar(year: context.year, month: context.month)
        async let dutiesResult = repository.duties(memberID: context.memberID, year: context.year, month: context.month)
        async let schedulesResult = repository.schedules(memberID: context.memberID, year: context.year, month: context.month)
        async let holidaysResult = repository.holidays(year: context.year, month: context.month)
        async let dDaysResult = repository.dDays(memberID: context.memberID, isMine: context.isMine)
        async let manageResult = context.isMine ? false : repository.canManage(memberID: context.memberID)
        async let todoResult: TodoBoardDTO? = context.isMine ? repository.todoBoard() : nil
        async let comparedResult = repository.otherDuties(memberIDs: Array(context.comparedMemberIDs.sorted().prefix(3)), year: context.year, month: context.month)

        let serverDays = try await calendarResult
        let cells = CalendarDateSupport.cells(year: context.year, month: context.month, serverDays: serverDays)
        guard cells.count == 42 else { throw APIError.invalidResponse }
        let duties = try await dutiesResult
        let schedules = try await schedulesResult
        let holidays = try await holidaysResult
        let loadedDDays = try await dDaysResult
        let loadedCanManage = try await manageResult
        let loadedTodoBoard = try await todoResult
        let compared = try await comparedResult
        guard isCurrentMonthRequest(context) else { return }
        canManage = loadedCanManage
        todoBoard = loadedTodoBoard
        dDays = loadedDDays.sorted { $0.date.rawValue < $1.date.rawValue }
        applyMonth(
            year: context.year,
            month: context.month,
            calendar: serverDays,
            schedules: schedules,
            duties: duties,
            holidays: holidays,
            compared: compared,
            memberID: context.memberID
        )
        await overlayPendingSchedules(for: context)
        guard isCurrentMonthRequest(context) else { return }
        isOfflineMode = false
        isShowingCachedData = false
        cacheStoredAt = nil
        if !serverRecoveryAttemptInProgress {
            cancelServerRecovery(clearPending: true)
        }

        guard isCurrentMonthRequest(context),
              context.isMine,
              let accountID = context.accountID,
              accountID == context.memberID
        else { return }
        // Cache writes are best effort. A filesystem failure must never turn an
        // otherwise successful online response into a user-visible error.
        try? await cache.saveMonth(OfflineMonthSnapshot(
            accountID: accountID,
            key: OfflineMonthKey(year: context.year, month: context.month),
            calendar: serverDays,
            schedules: schedules,
            duties: duties,
            holidays: holidays,
            otherDuties: compared
        ))
        guard isCurrentMonthRequest(context) else { return }
        if let member = me, member.id == accountID {
            try? await cache.saveAccount(OfflineAccountSnapshot(
                member: member,
                friends: friends,
                dDays: loadedDDays,
                storedAt: .now
            ))
        }
        guard isCurrentMonthRequest(context) else { return }
        if let board = todoBoard {
            try? await cache.saveTodoBoard(accountID: accountID, board: board, now: .now)
        }
    }

    private func applyCachedMonth(_ snapshot: OfflineMonthSnapshot, context: MonthRequestContext) {
        applyMonth(
            year: context.year,
            month: context.month,
            calendar: snapshot.calendar,
            schedules: snapshot.schedules,
            duties: snapshot.duties,
            holidays: snapshot.holidays,
            compared: snapshot.otherDuties,
            memberID: context.memberID
        )
        cacheStoredAt = snapshot.storedAt
    }

    private func applyMonth(
        year: Int,
        month: Int,
        calendar: [TeamDayDTO],
        schedules: [[ScheduleDTO]],
        duties: [DutyDTO],
        holidays: [[HolidayDTO]],
        compared: [OtherDutyResponse],
        memberID: MemberID
    ) {
        let cells = CalendarDateSupport.cells(year: year, month: month, serverDays: calendar)
        guard cells.count == 42 else { return }
        let activeTodos = (todoBoard?.todo ?? []) + (todoBoard?.inProgress ?? [])
        let pinKey = pinnedDDayKey(memberID)
        pinnedDDayID = UserDefaults.standard.object(forKey: pinKey) == nil ? nil : Int64(UserDefaults.standard.integer(forKey: pinKey))
        days = cells.enumerated().map { index, cell in
            CalendarDayContent(
                cell: cell,
                duty: duties.first { $0.year == cell.year && $0.month == cell.month && $0.day == cell.day },
                schedules: index < schedules.count ? schedules[index] : [],
                holidays: index < holidays.count ? holidays[index] : [],
                todos: activeTodos.filter { $0.dueDate == cell.date },
                dDays: dDays.filter { $0.date == cell.date },
                comparedDuties: compared.compactMap { response in
                    response.duties.first(where: { $0.year == cell.year && $0.month == cell.month && $0.day == cell.day })
                        .map {
                            ComparedDuty(
                                memberID: response.memberId,
                                name: response.name,
                                hasProfilePhoto: response.hasProfilePhoto,
                                profilePhotoVersion: response.profilePhotoVersion,
                                duty: $0
                            )
                        }
                }
            )
        }
        selectedDay = selectedDay.flatMap { selected in days.first { $0.id == selected.id } }
    }

    /// Refreshes the rolling thirteen-month self-calendar without delaying the
    /// visible month. Each month is fetched and persisted in order so a slow
    /// connection does not fan out thirteen requests at once.
    func prefetchCachedMonths(around current: OfflineMonthKey? = nil) async {
        guard !isOfflineMode, let accountID = cacheAccountID else { return }
        let current = current ?? OfflineMonthKey(year: year, month: month)
        for key in OfflineCacheRangePolicy.rollingThirteenMonths.months(around: current) {
            if Task.isCancelled { return }
            if let snapshot = await cache.loadMonth(accountID: accountID, key: key),
               Date().timeIntervalSince(snapshot.storedAt) < 24 * 60 * 60 {
                continue
            }
            do {
                async let calendarResult = repository.calendar(year: key.year, month: key.month)
                async let dutiesResult = repository.duties(memberID: accountID, year: key.year, month: key.month)
                async let schedulesResult = repository.schedules(memberID: accountID, year: key.year, month: key.month)
                async let holidaysResult = repository.holidays(year: key.year, month: key.month)
                async let comparedResult = repository.otherDuties(
                    memberIDs: Array(comparedMemberIDs.sorted().prefix(3)),
                    year: key.year,
                    month: key.month
                )
                let calendar = try await calendarResult
                let duties = try await dutiesResult
                let schedules = try await schedulesResult
                let holidays = try await holidaysResult
                let compared = try await comparedResult
                guard calendar.count == 42, schedules.count == 42, holidays.count == 42 else { continue }
                try? await cache.saveMonth(OfflineMonthSnapshot(
                    accountID: accountID,
                    key: key,
                    calendar: calendar,
                    schedules: schedules,
                    duties: duties,
                    holidays: holidays,
                    otherDuties: compared
                ))
            } catch is CancellationError {
                return
            } catch {
                // Prefetch is opportunistic; the visible month remains usable
                // when one future request fails.
                continue
            }
        }
    }

    private func startPrefetchIfNeeded() {
        // The authenticated root passes the verified session member ID. Keeping
        // this gate also prevents test doubles and deep-linked guest screens
        // from starting an unbounded background refresh.
        guard initialAccountID != nil, isMyCalendar else { return }
        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            await self?.prefetchCachedMonths()
        }
    }

    private func scheduleServerRecovery() {
        guard !prefersOfflineCache,
              isOfflineMode,
              isMyCalendar,
              let accountID = cacheAccountID
        else { return }
        serverRecoveryPending = true
        guard serverRecoveryTask == nil else { return }

        serverRecoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for attempt in CalendarServerRecoveryPolicy.delays.indices {
                guard self.isServerRecoveryCurrent(accountID: accountID),
                      let delay = CalendarServerRecoveryPolicy.delay(forAttempt: attempt)
                else { break }
                do {
                    try await self.serverRecoverySleeper(delay)
                } catch {
                    return
                }
                guard self.isServerRecoveryCurrent(accountID: accountID) else { return }
                switch await self.attemptServerRecovery(accountID: accountID) {
                case .recovered, .stop:
                    self.serverRecoveryPending = false
                    self.serverRecoveryTask = nil
                    return
                case .retry:
                    continue
                }
            }
            self.serverRecoveryPending = false
            self.serverRecoveryTask = nil
        }
    }

    private func attemptServerRecovery(accountID: MemberID) async -> CalendarServerRecoveryAttempt {
        guard isServerRecoveryCurrent(accountID: accountID) else { return .stop }
        serverRecoveryAttemptInProgress = true
        defer { serverRecoveryAttemptInProgress = false }
        let needsIdentity = serverRecoveryNeedsIdentity
        serverRecoveryNeedsIdentity = false
        prefersOfflineCache = false

        if needsIdentity {
            do {
                try await loadOnlineIdentity()
                guard isServerRecoveryAccountCurrent(accountID: accountID) else { return .stop }
            } catch {
                guard isServerRecoveryAccountCurrent(accountID: accountID) else { return .stop }
                guard isRecoverableOfflineError(error) else {
                    _ = await restoreCachedIdentity()
                    return .stop
                }
                guard await restoreCachedIdentity() else { return .stop }
                serverRecoveryNeedsIdentity = true
                return .retry
            }
        }

        do {
            try await loadMonth(
                scheduleRecovery: false,
                forceOnlineRequest: true
            )
        } catch {
            guard isServerRecoveryAccountCurrent(accountID: accountID) else { return .stop }
            isOfflineMode = true
            return isRecoverableOfflineError(error) ? .retry : .stop
        }
        guard isServerRecoveryAccountCurrent(accountID: accountID) else { return .stop }
        guard !isOfflineMode else { return .retry }

        let pendingEntries = await outbox.entries(accountID: accountID)
        if pendingEntries.contains(where: { $0.state == .pending }) {
            // A successful calendar response proves the server is reachable even
            // when NWPath has not changed. Ask the shared coordinator to drain
            // the account queue; the coordinator owns retry policy and haptics.
            await requestOfflineSync(accountID)
        }
        return .recovered
    }

    private func isServerRecoveryCurrent(accountID: MemberID) -> Bool {
        isServerRecoveryAccountCurrent(accountID: accountID)
            && !prefersOfflineCache
            && isOfflineMode
            && isMyCalendar
    }

    private func isServerRecoveryAccountCurrent(accountID: MemberID) -> Bool {
        !Task.isCancelled
            && cacheAccountID == accountID
            && isMyCalendar
    }

    private func cancelServerRecovery(clearPending: Bool) {
        serverRecoveryTask?.cancel()
        serverRecoveryTask = nil
        if clearPending {
            serverRecoveryPending = false
            serverRecoveryNeedsIdentity = false
        }
    }

    private func isRecoverableOfflineError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .transport:
            return true
        case .server(let status, _), .serverWithDetails(let status, _, _):
            return status >= 500
        default:
            return false
        }
    }

    /// A create response can be ambiguous even when the transport completed:
    /// an empty or malformed 2xx body may mean the server committed the row but
    /// the client could not decode its acknowledgement. Only the create path
    /// treats these response-shape errors as queueable; ordinary reads keep the
    /// stricter transport/5xx fallback policy.
    private func isRecoverableScheduleCreateError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .invalidResponse, .decoding:
            return true
        default:
            return isRecoverableOfflineError(error)
        }
    }

    private enum CalendarServerRecoveryAttempt {
        case recovered
        case retry
        case stop
    }

    func toggleMyDutyComparison() async {
        guard !isMyCalendar, let myID = me?.id else { return }
        comparedMemberIDs = comparedMemberIDs.contains(myID) ? [] : [myID]
        emit(.selection)
        await reloadMonth()
    }

#if DEBUG
    private func loadUITestingFixture() {
        let includesCalendarParity = ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar-parity")
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
        me = member
        selectedMemberID = member.id
        targetMember = nil
        let parityFriend = FriendDTO(
            id: 2,
            name: "Profile friend",
            teamId: nil,
            team: "Ward A",
            hasProfilePhoto: false,
            profilePhotoVersion: 17,
            isFamily: false,
            pinOrder: nil
        )
        friends = includesCalendarParity ? [parityFriend] : []
        team = nil
        // A page that already fits its screen cannot show a scroll either way, so the
        // scroll test asks for enough D-Days to push the calendar past the bottom.
        // The dates sit outside the grid so the cells themselves stay as they were.
        dDays = ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar-tall")
            ? (1...6).map { index in
                DDayDTO(
                    id: Int64(900 + index),
                    title: "D-Day \(index)",
                    date: DateOnly(rawValue: String(format: "2030-01-%02d", index)),
                    isPrivate: false,
                    calc: 0,
                    daysLeft: Int64(index)
                )
            }
            : []
        let parityTodo = TodoDTO(
            id: "A11CE000-0000-4000-8000-000000000011",
            title: "Calendar detail check",
            content: "Only this Todo detail should be visible.",
            position: 0,
            status: .inProgress,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
            completedDate: nil,
            dueDate: DateOnly(rawValue: "2026-08-12"),
            isOverdue: false,
            isTagged: false,
            owner: "UI Test",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
        todoBoard = TodoBoardDTO(
            todo: [],
            inProgress: includesCalendarParity ? [parityTodo] : [],
            done: [],
            counts: TodoCountsDTO(
                todo: 0,
                inProgress: includesCalendarParity ? 1 : 0,
                done: 0,
                total: includesCalendarParity ? 1 : 0
            )
        )
        comparedMemberIDs = includesCalendarParity ? [parityFriend.id] : []
        canManage = false
        errorMessage = nil
        let firstOfMonth = CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) ?? Date()
        let weekday = CalendarDateSupport.calendar.component(.weekday, from: firstOfMonth)
        let gridStart = CalendarDateSupport.calendar.date(
            byAdding: .day,
            value: -(weekday - CalendarDateSupport.calendar.firstWeekday + 7) % 7,
            to: firstOfMonth
        ) ?? firstOfMonth
        days = (0..<42).compactMap { offset in
            guard let date = CalendarDateSupport.calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
            guard let cellYear = parts.year, let cellMonth = parts.month, let cellDay = parts.day else {
                return nil
            }
            let cell = CalendarCell(
                date: DateOnly(rawValue: String(format: "%04d-%02d-%02d", cellYear, cellMonth, cellDay)),
                year: cellYear,
                month: cellMonth,
                day: cellDay,
                isCurrentMonth: cellYear == year && cellMonth == month
            )
            let comparedDuties: [ComparedDuty] = if includesCalendarParity && cell.isCurrentMonth && cell.day == 12 {
                [ComparedDuty(
                    memberID: parityFriend.id,
                    name: parityFriend.name,
                    hasProfilePhoto: parityFriend.hasProfilePhoto,
                    profilePhotoVersion: parityFriend.profilePhotoVersion,
                    duty: DutyDTO(
                        year: cell.year,
                        month: cell.month,
                        day: cell.day,
                        dutyType: "Day",
                        dutyColor: "#3B82F6",
                        isOff: false,
                        dutyTypeId: 7,
                        source: .override
                    )
                )]
            } else {
                []
            }
            return CalendarDayContent(
                cell: cell,
                duty: nil,
                schedules: [],
                holidays: [],
                todos: includesCalendarParity && parityTodo.dueDate == cell.date ? [parityTodo] : [],
                dDays: [],
                comparedDuties: comparedDuties
            )
        }
    }
#endif

    func setFriendDutyComparisons(_ memberIDs: Set<MemberID>) async {
        guard isMyCalendar else { return }
        let validIDs = Set(memberIDs.filter { candidate in
            friends.contains(where: { $0.id == candidate })
        }.prefix(3))
        guard validIDs != comparedMemberIDs else { return }
        comparedMemberIDs = validIDs
        emit(.selection)
        await reloadMonth()
    }

    func selectYearMonth(year: Int, month: Int, emitFeedback: Bool = true) async {
        guard (1...12).contains(month) else { return }
        let feedback = CalendarHapticPolicy.monthNavigation(
            fromYear: self.year,
            fromMonth: self.month,
            toYear: year,
            toMonth: month
        )
        self.year = year
        self.month = month
        if emitFeedback, feedback != nil { emit(.routine) }
        await reloadMonth()
    }

    func setQuickDutyEditing(_ enabled: Bool, emitFeedback: Bool = true) {
        guard !enabled || canEdit else { return }
        guard isQuickDutyEditing != enabled else { return }
        isQuickDutyEditing = enabled
        quickDutyDay = enabled ? (days.first(where: { $0.cell.date == highlightedDate && $0.cell.isCurrentMonth }) ?? days.first(where: \.cell.isCurrentMonth)) : nil
        if emitFeedback { emit(.selection) }
    }

    func focusQuickDuty(on day: CalendarDayContent, emitFeedback: Bool = true) {
        guard canEdit, day.cell.isCurrentMonth else { return }
        let previousDate = quickDutyDay?.cell.date
        quickDutyDay = day
        highlightedDate = day.cell.date
        if emitFeedback,
           CalendarHapticPolicy.selectionChanged(from: previousDate, to: day.cell.date) != nil {
            emit(.selection)
        }
    }

    func selectDay(_ day: CalendarDayContent) {
        let previousDate = selectedDay?.cell.date
        selectedDay = day
        if CalendarHapticPolicy.selectionChanged(from: previousDate, to: day.cell.date) != nil {
            emit(.selection)
        }
    }

    func moveQuickDutyFocus(by offset: Int) {
        let currentMonthDays = days.filter(\.cell.isCurrentMonth)
        guard !currentMonthDays.isEmpty else { return }
        let currentIndex = quickDutyDay.flatMap { selected in currentMonthDays.firstIndex(where: { $0.id == selected.id }) } ?? 0
        let index = min(max(currentIndex + offset, 0), currentMonthDays.count - 1)
        focusQuickDuty(on: currentMonthDays[index])
    }

    func applyQuickDuty(dutyTypeID: DutyTypeID?) async {
        guard canEdit, let day = quickDutyDay, let memberID = targetMemberID else { return }
        let currentMonthDays = days.filter(\.cell.isCurrentMonth)
        let nextDate = currentMonthDays.firstIndex(where: { $0.id == day.id }).flatMap { index in
            currentMonthDays.indices.contains(index + 1) ? currentMonthDays[index + 1].cell.date : nil
        }
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
            if let nextDate, let next = days.first(where: { $0.cell.date == nextDate }) {
                focusQuickDuty(on: next, emitFeedback: false)
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func changeMonth(by offset: Int) async {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let date = CalendarDateSupport.calendar.date(from: components),
              let changed = CalendarDateSupport.calendar.date(byAdding: .month, value: offset, to: date)
        else { return }
        components = CalendarDateSupport.calendar.dateComponents([.year, .month], from: changed)
        let nextYear = components.year ?? year
        let nextMonth = components.month ?? month
        guard CalendarHapticPolicy.monthNavigation(
            fromYear: year,
            fromMonth: month,
            toYear: nextYear,
            toMonth: nextMonth
        ) != nil else { return }
        year = nextYear
        month = nextMonth
        emit(.routine)
        await reloadMonth()
    }

    func goToToday(emitFeedback: Bool = true) async {
        let components = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        let nextYear = components.year ?? year
        let nextMonth = components.month ?? month
        let nextDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", nextYear, nextMonth, components.day ?? 1))
        let monthChanged = CalendarHapticPolicy.monthNavigation(
            fromYear: year,
            fromMonth: month,
            toYear: nextYear,
            toMonth: nextMonth
        ) != nil
        let dateChanged = CalendarHapticPolicy.selectionChanged(from: highlightedDate, to: nextDate) != nil
        year = nextYear
        month = nextMonth
        highlightedDate = nextDate
        if emitFeedback, monthChanged || dateChanged { emit(.routine) }
        await reloadMonth()
    }

    var pinnedDDay: DDayDTO? { dDays.first { $0.id == pinnedDDayID } }

    func togglePinnedDDay(_ item: DDayDTO) {
        guard let memberID = targetMemberID else { return }
        if pinnedDDayID == item.id {
            pinnedDDayID = nil
            UserDefaults.standard.removeObject(forKey: pinnedDDayKey(memberID))
        } else {
            pinnedDDayID = item.id
            UserDefaults.standard.set(item.id, forKey: pinnedDDayKey(memberID))
        }
        emit(.selection)
    }

    func refreshTodoBoard() async {
        guard isMyCalendar else { return }
        do {
            todoBoard = try await repository.todoBoard()
            if let accountID = cacheAccountID, let todoBoard {
                try? await cache.saveTodoBoard(accountID: accountID, board: todoBoard, now: .now)
            }
            rebuildTodoDays()
        } catch {
            if isRecoverableOfflineError(error),
               let accountID = cacheAccountID,
               let cached = await cache.loadTodoBoard(accountID: accountID) {
                todoBoard = cached
                isOfflineMode = true
                rebuildTodoDays()
            } else {
                errorMessage = CalendarLocalization.text("calendar.error.load")
                emit(.error)
            }
        }
    }

    func updateDuty(day: CalendarDayContent, dutyTypeID: DutyTypeID?) async {
        guard canEdit, let memberID = targetMemberID else { return }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return
        }
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func batchUpdateDuty(dutyTypeID: DutyTypeID?) async {
        guard isMyCalendar, let memberID = targetMemberID else { return }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return
        }
        do {
            try await repository.batchUpdateDuty(DutyBatchUpdateDTO(
                year: year, month: month, dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func uploadDutyBatch(url: URL) async {
        guard isMyCalendar, let template = team?.dutyBatchTemplate, let memberID = targetMemberID else { return }
        guard !isOfflineMode else {
            dutyBatchMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return
        }
        guard CalendarFeatureLogic.isSupportedDutyBatchFile(
            fileName: url.lastPathComponent,
            fileExtensions: template.fileExtensions
        ) else {
            dutyBatchMessage = CalendarFeatureLogic.dutyBatchFailureMessage(
                errorCode: "dutyBatch.notSupportedFile",
                details: [
                    "supportedFile": .string(
                        CalendarFeatureLogic.normalizedFileExtensions(template.fileExtensions)
                            .joined(separator: ", ")
                    )
                ]
            )
            emit(.warning)
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < AttachmentUploadPolicy.safeMaximumBytes else {
                dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.tooLarge")
                emit(.warning)
                return
            }
            let result = try await repository.uploadDutyBatch(
                memberID: memberID, year: year, month: month,
                filename: url.lastPathComponent, data: data
            )
            if result.result {
                let period = if let start = result.startDate, let end = result.endDate {
                    CalendarLocalization.format("calendar.duty.excel.period", start.rawValue, end.rawValue)
                } else { "" }
                dutyBatchMessage = [period, CalendarLocalization.format("calendar.duty.excel.success", result.workingDays, result.offDays)]
                    .filter { !$0.isEmpty }.joined(separator: "\n")
                emit(.success)
                do {
                    try await refreshDuties()
                } catch {
                    dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.failed")
                }
            } else {
                dutyBatchMessage = CalendarFeatureLogic.dutyBatchFailureMessage(result)
                emit(.error)
            }
        } catch {
            dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.failed")
            emit(.error)
        }
    }

    func saveSchedule(
        existing: ScheduleDTO?, content: String, description: String,
        visibility: Visibility, start: Date, end: Date, tagFriendIDs: [MemberID],
        attachmentSessionID: UUID?, orderedAttachmentIDs: [AttachmentID],
        aiTimeParsingRequested: Bool
    ) async -> Bool {
        guard canEdit, let memberID = targetMemberID else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50, end >= start else {
            emit(.warning)
            return false
        }
        guard !contentFilter.isBlocked(trimmed, description) else {
            errorMessage = CalendarLocalization.text("calendar.error.contentFilter")
            emit(.error)
            return false
        }
        if isOfflineMode {
            guard existing == nil else {
                errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
                emit(.warning)
                return false
            }
            guard tagFriendIDs.isEmpty,
                  attachmentSessionID == nil,
                  orderedAttachmentIDs.isEmpty,
                  !aiTimeParsingRequested
            else {
                errorMessage = CalendarLocalization.text("calendar.offline.scheduleLimit")
                emit(.warning)
                return false
            }
        }

        // Generate the local outbox operation before the first create request
        // so a recoverable response can retain one durable operation. The
        // server applies the content-based duplicate policy to every create.
        let operationID = existing == nil ? UUID() : nil
        let request = ScheduleSaveDTO(
            id: existing?.id,
            memberId: memberID,
            content: trimmed,
            description: description,
            visibility: visibility,
            startDateTime: CalendarDateSupport.localDateTime(start),
            endDateTime: CalendarDateSupport.localDateTime(end),
            tagFriendIds: isMyCalendar ? tagFriendIDs : nil,
            attachmentSessionId: attachmentSessionID,
            orderedAttachmentIds: orderedAttachmentIDs,
            aiTimeParsingRequested: aiTimeParsingRequested
        )

        if isOfflineMode {
            guard let accountID = cacheAccountID, let operationID else { return false }
            do {
                _ = try await outbox.enqueueScheduleCreate(
                    accountID: accountID,
                    request: request,
                    operationID: operationID,
                    now: .now
                )
                appendProvisionalSchedule(request, provisionalID: operationID)
                pendingScheduleCount = pendingScheduleEntryCount(
                    await outbox.entries(accountID: accountID)
                )
                // A durable local acknowledgement is a completed user action.
                // Automatic outbox draining remains silent elsewhere.
                emit(.success)
                return true
            } catch {
                // Storage failure must not manufacture a false local success.
                errorMessage = CalendarLocalization.text("calendar.error.save")
                return false
            }
        }

        do {
            let savedResponse: ScheduleSaveResponse
            savedResponse = try await repository.saveSchedule(request)
            emit(.success)
            do {
                try await refreshSchedules()
            } catch {
                // The POST has already completed. Keep that durable success even
                // if the follow-up read is unavailable, preserve the visible
                // mutation locally, and let the bounded recovery refresh it.
                if existing == nil {
                    appendProvisionalSchedule(
                        request,
                        provisionalID: savedResponse.id
                    )
                }
                await persistCurrentMonthCache(allowOffline: true)
                if isRecoverableOfflineError(error) {
                    isOfflineMode = true
                    scheduleServerRecovery()
                    await Task.yield()
                }
            }
            return true
        } catch {
            if existing == nil,
               isMyCalendar,
               isRecoverableScheduleCreateError(error),
               let accountID = cacheAccountID,
               let operationID,
               tagFriendIDs.isEmpty,
               attachmentSessionID == nil,
               orderedAttachmentIDs.isEmpty,
               !aiTimeParsingRequested {
                isOfflineMode = true
                do {
                    _ = try await outbox.enqueueScheduleCreate(
                        accountID: accountID,
                        request: request,
                        operationID: operationID,
                        now: .now
                    )
                    appendProvisionalSchedule(request, provisionalID: operationID)
                    pendingScheduleCount = pendingScheduleEntryCount(
                        await outbox.entries(accountID: accountID)
                    )
                    emit(.success)
                    // A recoverable create may be an ambiguous response. Ask
                    // the shared coordinator to drain immediately so an
                    // unchanged NWPath cannot leave the durable queue waiting.
                    let sync = requestOfflineSync
                    Task { @MainActor in
                        await sync(accountID)
                    }
                    return true
                } catch {
                    // A queue write failure is intentionally quiet with respect
                    // to haptics and leaves the normal online behavior available.
                    isOfflineMode = false
                    errorMessage = CalendarLocalization.text("calendar.error.save")
                    return false
                }
            }
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
            return false
        }
    }

    func deleteSchedule(_ schedule: ScheduleDTO) async -> Bool {
        guard canEdit, !schedule.isTagged else { return false }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return false
        }
        do {
            try await repository.deleteSchedule(id: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeSchedule(id: schedule.id)
        await persistCurrentMonthCache(allowOffline: true)
        emit(.success)
        return true
    }

    func untagSelf(_ schedule: ScheduleDTO) async -> Bool {
        guard isMyCalendar, schedule.isTagged else { return false }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return false
        }
        do {
            try await repository.untagSelf(scheduleID: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeSchedule(id: schedule.id)
        await persistCurrentMonthCache(allowOffline: true)
        emit(.success)
        return true
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, let memberID = targetMemberID, !query.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await repository.searchSchedules(memberID: memberID, query: query, page: 0)
            searchResults = response.content
            searchPage = 0
            canLoadMoreSearchResults = !response.last
        }
        catch {
            if isRecoverableOfflineError(error), isMyCalendar,
               let accountID = cacheAccountID,
               await useCachedSearch(query: query, accountID: accountID) {
                isOfflineMode = true
                scheduleServerRecovery()
                await Task.yield()
                return
            }
            errorMessage = CalendarLocalization.text("calendar.error.search")
            emit(.error)
        }
    }

    func loadMoreSearchResults() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, let memberID = targetMemberID, !query.isEmpty, canLoadMoreSearchResults, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let nextPage = searchPage + 1
            let response = try await repository.searchSchedules(memberID: memberID, query: query, page: nextPage)
            searchResults.append(contentsOf: response.content)
            searchPage = nextPage
            canLoadMoreSearchResults = !response.last
        } catch {
            if isRecoverableOfflineError(error), isMyCalendar,
               let accountID = cacheAccountID,
               await useCachedSearch(query: query, accountID: accountID) {
                isOfflineMode = true
                scheduleServerRecovery()
                await Task.yield()
                return
            }
            errorMessage = CalendarLocalization.text("calendar.error.search")
            emit(.error)
        }
    }

    private func useCachedSearch(query: String, accountID: MemberID) async -> Bool {
        let keys = OfflineCacheRangePolicy.rollingThirteenMonths.months(
            around: OfflineMonthKey(year: year, month: month)
        )
        guard !(await cache.loadCachedMonths(accountID: accountID, around: OfflineMonthKey(year: year, month: month))).isEmpty
        else { return false }
        searchResults = await cache.searchSchedules(accountID: accountID, query: query, keys: keys)
        searchPage = 0
        canLoadMoreSearchResults = false
        return true
    }

    func showSearchResult(_ result: ScheduleSearchResultDTO) async {
        guard let date = CalendarDateSupport.date(from: result.startDateTime) else { return }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        let nextYear = parts.year ?? year
        let nextMonth = parts.month ?? month
        let nextDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", nextYear, nextMonth, parts.day ?? 1))
        year = nextYear
        month = nextMonth
        highlightedDate = nextDate
        await reloadMonth()
    }

    func saveDDay(existing: DDayDTO?, title: String, date: Date, isPrivate: Bool) async -> Bool {
        guard isMyCalendar else { return false }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return false
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else {
            emit(.warning)
            return false
        }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        let dateOnly = DateOnly(rawValue: String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
        do {
            let saved = try await repository.saveDDay(
                DDaySaveDTO(id: existing?.id, title: trimmed, date: dateOnly, isPrivate: isPrivate)
            )
            upsertDDay(saved)
            await persistAccountCache()
            emit(.success)
            return true
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
            return false
        }
    }

    func deleteDDay(_ dDay: DDayDTO) async -> Bool {
        guard isMyCalendar else { return false }
        guard !isOfflineMode else {
            errorMessage = CalendarLocalization.text("calendar.offline.onlineOnly")
            emit(.warning)
            return false
        }
        do {
            try await repository.deleteDDay(id: dDay.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeDDay(id: dDay.id)
        await persistAccountCache()
        emit(.success)
        return true
    }

    private func refreshSchedules() async throws {
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let loadedSchedules = try await repository.schedules(
            memberID: memberID,
            year: year,
            month: month
        )
        days = days.enumerated().map { index, day in
            replacing(day, schedules: loadedSchedules.indices.contains(index) ? loadedSchedules[index] : [])
        }
        rebindPresentedDays()
        await persistCurrentMonthCache()
    }

    private func refreshDuties() async throws {
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let loadedDuties = try await repository.duties(
            memberID: memberID,
            year: year,
            month: month
        )
        days = days.map { day in
            let duty = loadedDuties.first {
                $0.year == day.cell.year && $0.month == day.cell.month && $0.day == day.cell.day
            }
            return CalendarDayContent(
                cell: day.cell,
                duty: duty,
                schedules: day.schedules,
                holidays: day.holidays,
                todos: day.todos,
                dDays: day.dDays,
                comparedDuties: day.comparedDuties
            )
        }
        rebindPresentedDays()
        await persistCurrentMonthCache()
    }

    private func rebuildTodoDays() {
        let visibleTodos = (todoBoard?.todo ?? []) + (todoBoard?.inProgress ?? [])
        days = days.map { day in
            replacing(day, todos: visibleTodos.filter { $0.dueDate == day.cell.date })
        }
        rebindPresentedDays()
    }

    private func persistCurrentMonthCache(allowOffline: Bool = false) async {
        guard (allowOffline || !isOfflineMode),
              let accountID = cacheAccountID,
              isMyCalendar,
              days.count == 42
        else { return }
        let key = OfflineMonthKey(year: year, month: month)
        let existing = await cache.loadMonth(accountID: accountID, key: key)
        let calendar = days.map { TeamDayDTO(year: $0.cell.year, month: $0.cell.month, day: $0.cell.day) }
        let duties = days.compactMap(\.duty)
        let holidays = days.map(\.holidays)
        let schedules = days.map(\.schedules)
        try? await cache.saveMonth(OfflineMonthSnapshot(
            accountID: accountID,
            key: key,
            calendar: calendar,
            schedules: schedules,
            duties: duties,
            holidays: holidays,
            otherDuties: existing?.otherDuties ?? []
        ))
    }

    private func removeSchedule(id: ScheduleID) {
        days = days.map { day in
            replacing(day, schedules: day.schedules.filter { $0.id != id })
        }
        rebindPresentedDays()
    }

    private func persistAccountCache() async {
        guard let member = me, member.id == cacheAccountID else { return }
        try? await cache.saveAccount(OfflineAccountSnapshot(
            member: member,
            friends: friends,
            dDays: dDays,
            storedAt: .now
        ))
    }

    private func appendProvisionalSchedule(
        _ request: ScheduleSaveDTO,
        provisionalID: UUID
    ) {
        guard let start = CalendarDateSupport.date(from: request.startDateTime),
              let end = CalendarDateSupport.date(from: request.endDateTime)
        else { return }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: start)
        let endParts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: end)
        guard let startYear = parts.year, let startMonth = parts.month, let startDay = parts.day else { return }
        let startDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", startYear, startMonth, startDay))
        let endDate = DateOnly(rawValue: String(
            format: "%04d-%02d-%02d",
            endParts.year ?? startYear,
            endParts.month ?? startMonth,
            endParts.day ?? startDay
        ))
        let totalDays = max(
            1,
            (CalendarDateSupport.calendar.dateComponents(
                [.day],
                from: CalendarDateSupport.date(from: startDate) ?? start,
                to: CalendarDateSupport.date(from: endDate) ?? end
            ).day ?? 0) + 1
        )
        let position = (days.first { $0.cell.date == startDate }?.schedules.map(\.position).max() ?? -1) + 1
        let calendar = CalendarDateSupport.calendar
        guard let startDayDate = CalendarDateSupport.date(from: startDate),
              let endDayDate = CalendarDateSupport.date(from: endDate)
        else { return }
        var updatedDays = days
        for index in updatedDays.indices {
            let current = updatedDays[index].cell.date
            guard let currentDate = CalendarDateSupport.date(from: current),
                  currentDate >= startDayDate,
                  currentDate <= endDayDate
            else { continue }
            let daysFromStart = (calendar.dateComponents(
                [.day],
                from: startDayDate,
                to: currentDate
            ).day ?? 0) + 1
            let provisional = ScheduleDTO(
                id: provisionalID,
                content: request.content,
                description: request.description,
                position: position,
                year: updatedDays[index].cell.year,
                month: updatedDays[index].cell.month,
                dayOfMonth: updatedDays[index].cell.day,
                startDateTime: request.startDateTime,
                endDateTime: request.endDateTime,
                isTagged: false,
                owner: me?.name ?? "",
                taggedByMember: nil,
                tags: [],
                visibility: request.visibility,
                dateToCompare: current,
                attachments: [],
                startDate: startDate,
                daysFromStart: daysFromStart,
                endDate: endDate,
                curDate: current,
                totalDays: totalDays
            )
            let schedules = updatedDays[index].schedules.filter { $0.id != provisionalID } + [provisional]
            updatedDays[index] = replacing(updatedDays[index], schedules: schedules)
        }
        days = updatedDays
        rebindPresentedDays()
    }

    private func overlayPendingSchedules(for context: MonthRequestContext) async {
        guard isCurrentMonthRequest(context),
              let accountID = context.accountID,
              let memberID = me?.id,
              memberID == accountID
        else { return }
        let entries = await outbox.entries(accountID: accountID)
        guard isCurrentMonthRequest(context) else { return }
        pendingScheduleCount = pendingScheduleEntryCount(entries)
        for entry in entries where entry.state == .pending {
            guard case .scheduleCreate(let request) = entry.payload,
                  let start = CalendarDateSupport.date(from: request.startDateTime)
            else { continue }
            let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: start)
            guard parts.year == context.year, parts.month == context.month else { continue }
            appendProvisionalSchedule(request, provisionalID: entry.operationID)
        }
    }

    private func pendingScheduleEntryCount(_ entries: [OfflineOutboxEntry]) -> Int {
        entries.filter {
            $0.state == .pending && $0.kind == .scheduleCreate
        }.count
    }

    private func upsertDDay(_ item: DDayDTO) {
        dDays.removeAll { $0.id == item.id }
        dDays.append(item)
        dDays.sort { $0.date.rawValue < $1.date.rawValue }
        rebuildDDayDays()
    }

    private func removeDDay(id: Int64) {
        dDays.removeAll { $0.id == id }
        if pinnedDDayID == id, let memberID = targetMemberID {
            pinnedDDayID = nil
            UserDefaults.standard.removeObject(forKey: pinnedDDayKey(memberID))
        }
        rebuildDDayDays()
    }

    private func rebuildDDayDays() {
        days = days.map { day in
            replacing(day, dDays: dDays.filter { $0.date == day.cell.date })
        }
        rebindPresentedDays()
    }

    private func rebindPresentedDays() {
        selectedDay = selectedDay.flatMap { selected in days.first { $0.id == selected.id } }
        quickDutyDay = quickDutyDay.flatMap { selected in days.first { $0.id == selected.id } }
    }

    private func replacing(
        _ day: CalendarDayContent,
        schedules: [ScheduleDTO]? = nil,
        todos: [TodoDTO]? = nil,
        dDays: [DDayDTO]? = nil
    ) -> CalendarDayContent {
        CalendarDayContent(
            cell: day.cell,
            duty: day.duty,
            schedules: schedules ?? day.schedules,
            holidays: day.holidays,
            todos: todos ?? day.todos,
            dDays: dDays ?? day.dDays,
            comparedDuties: day.comparedDuties
        )
    }

    private func reloadMonth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await loadMonth() }
        catch is CancellationError { return }
        catch {
            errorMessage = CalendarLocalization.text("calendar.error.load")
            emit(.error)
        }
    }

    private func pinnedDDayKey(_ memberID: MemberID) -> String { "selectedDday_\(memberID)" }

    private func emit(_ kind: DPHapticKind) {
        hapticCenter.emit(kind)
    }
}

enum CalendarFeatureLogic {
    static func dutyBatchFailureMessage(_ result: DutyBatchUploadResult) -> String {
        dutyBatchFailureMessage(errorCode: result.errorCode, details: result.errorDetails)
    }

    static func dutyBatchFailureMessage(errorCode: String?, details: [String: JSONValue]?) -> String {
        if let errorCode {
            let localized = CalendarLocalization.text(errorCode, table: "Errors")
            if localized != errorCode { return interpolate(localized, details: details) }
        }
        return CalendarLocalization.text("calendar.duty.excel.failed")
    }

    static func normalizedFileExtensions(_ fileExtensions: [String]) -> [String] {
        var seen = Set<String>()
        return fileExtensions.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return ".\(normalized)"
        }
    }

    static func isSupportedDutyBatchFile(fileName: String, fileExtensions: [String]) -> Bool {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return normalizedFileExtensions(fileExtensions).contains(".\(fileExtension)")
    }

    private static func interpolate(_ message: String, details: [String: JSONValue]?) -> String {
        details?.reduce(into: message) { result, entry in
            result = result.replacingOccurrences(of: "{\(entry.key)}", with: display(entry.value))
        } ?? message
    }

    private static func display(_ value: JSONValue) -> String {
        switch value {
        case .string(let value): value
        case .integer(let value): String(value)
        case .number(let value): String(value)
        case .boolean(let value): String(value)
        case .array(let values): values.map(display).joined(separator: ", ")
        case .object(let values): values.sorted(by: { $0.key < $1.key }).map { "\($0.key): \(display($0.value))" }.joined(separator: ", ")
        case .null: "-"
        }
    }
}
