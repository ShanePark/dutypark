import SwiftUI

func homeLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Home", locale: locale)
}

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var pinningMemberID: MemberID?
    @State private var inlinePinnedOrder: [MemberID]?
    @State private var draggedPinnedFriendID: MemberID?
    /// The card the finger is currently down on, as reported by the reorder
    /// recognizer. Only the press progress ring reads it.
    @State private var pressedPinnedFriendID: MemberID?
    @State private var pinnedDragLocation: CGPoint?
    @State private var pinnedDragPreviewSize: CGSize?
    @State private var pinnedDragGrabOffset: CGSize?
    @State private var pinnedFriendDropTargets: [DPPinnedFriendDropTarget] = []
    @State private var pinnedDragReferenceTargets: [DPPinnedFriendDropTarget] = []
    @State private var pinnedDragOriginalOrder: [MemberID] = []
    @State private var isSavingPinnedOrder = false
    @State private var showsPinnedOrderError = false
    @State private var suppressFriendCardActions = false
    private let refreshID: Int
    private let onRoute: (HomeRoute) -> Void
    private let pinRepository: any SocialRepository

    init(
        service: any HomeDashboardServing = HomeDashboardService(),
        pinRepository: any SocialRepository = LiveSocialRepository(),
        refreshID: Int = 0,
        onRoute: @escaping (HomeRoute) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(service: service))
        self.pinRepository = pinRepository
        self.refreshID = refreshID
        self.onRoute = onRoute
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.large) {
                myDashboardPanel
                friendsDashboardPanel
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.large)
        }
        .background(DPColor.backgroundSecondary)
        .task(id: refreshID) {
            if refreshID == 0 {
                await viewModel.loadIfNeeded()
            } else {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .coordinateSpace(name: HomePinnedFriendDragCoordinateSpace.name)
        .onPreferenceChange(DPPinnedFriendDropTargetPreferenceKey.self) {
            pinnedFriendDropTargets = $0
        }
        .scrollDisabled(draggedPinnedFriendID != nil)
        .dpDragFeedback(dragID: draggedPinnedFriendID)
        .dpDragRetargetFeedback(target: pinnedDragRetargetSlot)
        .overlay {
            if let draggedPinnedFriendID,
               let pinnedDragLocation,
               let pinnedDragPreviewSize,
               let pinnedDragGrabOffset,
               let friend = displayedPinnedFriends.first(where: {
                   $0.member.id == draggedPinnedFriendID
               }) {
                FriendSummaryCard(
                    friend: friend,
                    isPinning: false,
                    isDragPreview: true,
                    openCalendar: {},
                    togglePin: {}
                )
                .frame(width: pinnedDragPreviewSize.width, height: pinnedDragPreviewSize.height)
                .dpDragLift(tint: DPColor.accent, cornerRadius: DPRadius.large)
                .position(
                    x: pinnedDragLocation.x - pinnedDragGrabOffset.width,
                    y: pinnedDragLocation.y - pinnedDragGrabOffset.height
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .alert(
            Text("home.error.reorder", tableName: "Home"),
            isPresented: $showsPinnedOrderError
        ) {
            Button {} label: {
                Text("home.action.ok", tableName: "Home")
            }
        }
        .accessibilityIdentifier("home.dashboard")
    }

    private var myDashboardPanel: some View {
        VStack(spacing: 0) {
            if let dashboard = viewModel.myDashboard {
                Button {
                    openCalendar(for: dashboard.member.id)
                } label: {
                    HStack(spacing: DPSpacing.compact) {
                        HomeAvatar(
                            memberId: dashboard.member.id,
                            name: dashboard.member.name,
                            hasProfilePhoto: dashboard.member.hasProfilePhoto,
                            profilePhotoVersion: dashboard.member.profilePhotoVersion,
                            size: 36
                        )
                        Text(dashboard.member.name)
                            .font(DPTypography.heading)
                            .foregroundStyle(DPColor.textOnDark)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DPColor.textOnDarkMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, DPSpacing.compact)
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                    .background(HomePanelHeaderBackground())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("home.openCalendar", tableName: "Home") + Text(" \(dashboard.member.name)")
                )
            } else {
                panelHeader(title: Text("home.myDashboard", tableName: "Home"), systemImage: "person.fill")
            }

            Group {
                switch viewModel.myState {
                case .idle, .loading:
                    loadingState
                case .failed:
                    errorState(title: "home.error.my") {
                        await viewModel.retryMyDashboard()
                    }
                case .loaded(let dashboard):
                    myDashboardContent(dashboard)
                }
            }
            .frame(minHeight: 150)
        }
        .homeCard()
    }

    private func myDashboardContent(_ dashboard: DashboardMyDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(Date.now, format: .dateTime.year().month(.wide).day().weekday(.wide))
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
            }

            HStack(spacing: DPSpacing.small) {
                Image(systemName: "briefcase")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
                Text("home.duty", tableName: "Home")
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textSecondary)
                if let duty = dashboard.duty {
                    DutyBadge(duty: duty)
                } else {
                    Text("home.none", tableName: "Home")
                        .font(DPTypography.body)
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            .padding(.top, DPSpacing.compact)

            Divider()
                .padding(.top, 20)
                .padding(.bottom, DPSpacing.medium)

            Label {
                Text("home.todaySchedules", tableName: "Home")
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(.bottom, DPSpacing.small)

            if dashboard.schedules.isEmpty {
                Text("home.noSchedules", tableName: "Home")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
            } else {
                ForEach(dashboard.schedules, id: \.id) { schedule in
                    HomeScheduleRow(schedule: schedule)
                    if schedule.id != dashboard.schedules.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
    }

    private var friendsDashboardPanel: some View {
        VStack(spacing: 0) {
            Button { onRoute(.friends) } label: {
                panelHeader(
                    title: Text("home.friends", tableName: "Home"),
                    systemImage: "person.2.fill",
                    count: viewModel.sortedFriends.count
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("home.friends", tableName: "Home"))
            .accessibilityValue(String(viewModel.sortedFriends.count))
            .accessibilityIdentifier("home.friends.total")

            Group {
                switch viewModel.friendsState {
                case .idle, .loading:
                    loadingState
                case .failed:
                    errorState(title: "home.error.friends") {
                        await viewModel.retryFriendsDashboard()
                    }
                case .loaded:
                    friendsDashboardContent
                }
            }
            .frame(minHeight: 180)
        }
        .homeCard()
    }

    private var friendsDashboardContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            if viewModel.sortedFriends.isEmpty {
                VStack(spacing: DPSpacing.compact) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(DPColor.textMuted)
                    Text("home.noFriends", tableName: "Home")
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.extraLarge)
                .accessibilityIdentifier("home.friends.empty")
            } else {
                LazyVStack(spacing: DPSpacing.small) {
                    ForEach(displayedFriends, id: \.member.id) { friend in
                        FriendSummaryCard(
                            friend: friend,
                            isPinning: pinningMemberID == friend.member.id,
                            isDragPreview: false,
                            openCalendar: { openFriendCalendar(for: friend.member.id) },
                            togglePin: { requestTogglePin(friend) }
                        )
                        .dpDragSourceSlot(
                            isLifted: draggedPinnedFriendID == friend.member.id,
                            tint: DPColor.accent,
                            cornerRadius: DPRadius.large
                        )
                        .background {
                            if friend.pinOrder != nil, let memberID = friend.member.id {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: DPPinnedFriendDropTargetPreferenceKey.self,
                                        value: [DPPinnedFriendDropTarget(
                                            memberID: memberID,
                                            frame: proxy.frame(
                                                in: .named(HomePinnedFriendDragCoordinateSpace.name)
                                            )
                                        )]
                                    )
                                }
                            }
                        }
                        .modifier(pinnedFriendReorderGesture(friend))
                        .dpPressProgress(
                            isPressing: pressedPinnedFriendID == friend.member.id,
                            isDragging: draggedPinnedFriendID == friend.member.id,
                            tint: DPColor.accent
                        )
                        .accessibilityAction(
                            named: Text("home.action.moveUp", tableName: "Home")
                        ) {
                            movePinnedFriend(friend, offset: -1)
                        }
                        .accessibilityAction(
                            named: Text("home.action.moveDown", tableName: "Home")
                        ) {
                            movePinnedFriend(friend, offset: 1)
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func panelHeader(title: Text, systemImage: String, count: Int? = nil) -> some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
            title.font(DPTypography.bodyMedium)
            if let count, count > 0 {
                Text("\(count)")
                    .font(DPTypography.caption)
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, 2)
                    .background(DPColor.textOnDark.opacity(0.2))
                    .clipShape(Capsule())
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DPColor.textOnDarkMuted)
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, count == nil ? 20 : DPSpacing.large)
        .padding(.vertical, DPSpacing.compact)
        .frame(minHeight: count == nil ? 60 : 48)
        .background(HomePanelHeaderBackground())
    }

    private var loadingState: some View {
        VStack(spacing: DPSpacing.small) {
            ProgressView()
                .tint(DPColor.textPrimary)
            Text("home.loading", tableName: "Home")
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.large)
        .accessibilityIdentifier("home.loading")
    }

    private func errorState(
        title: LocalizedStringKey,
        retry: @escaping () async -> Void
    ) -> some View {
        VStack(spacing: DPSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(DPColor.danger)
            Text(title, tableName: "Home")
                .font(DPTypography.heading)
                .multilineTextAlignment(.center)
                .foregroundStyle(DPColor.textPrimary)
            Text("home.error.message", tableName: "Home")
                .font(DPTypography.label)
                .multilineTextAlignment(.center)
                .foregroundStyle(DPColor.textSecondary)
            Button {
                Task { await retry() }
            } label: {
                Text("home.retry", tableName: "Home")
            }
            .buttonStyle(DPPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.large)
        .accessibilityIdentifier("home.error")
    }

    private func openCalendar(for memberId: MemberID?) {
        guard let memberId else { return }
        onRoute(.memberCalendar(memberId))
    }

    private func openFriendCalendar(for memberId: MemberID?) {
        guard !consumeDragSuppression() else { return }
        openCalendar(for: memberId)
    }

    /// A reorder drag keeps the pressed control alive underneath the finger — the
    /// card moves with the drag, so the lift still lands inside the control that
    /// started it. Every control on a friend card therefore has to swallow the
    /// lift that ends a drag; the flag is only set once a drag has begun, so plain
    /// taps are untouched. The check has to run synchronously inside the control's
    /// action, before any `Task`, because the suppression is released on the next
    /// main-queue turn.
    private func consumeDragSuppression() -> Bool {
        guard suppressFriendCardActions else { return false }
        suppressFriendCardActions = false
        return true
    }

    private func requestTogglePin(_ friend: DashboardFriendDetailDTO) {
        guard !consumeDragSuppression() else { return }
        Task { await togglePin(friend) }
    }

    private var pinnedFriends: [DashboardFriendDetailDTO] {
        viewModel.sortedFriends.filter { $0.pinOrder != nil }
    }

    private var displayedPinnedFriends: [DashboardFriendDetailDTO] {
        guard let inlinePinnedOrder else { return pinnedFriends }
        let positions = Dictionary(
            uniqueKeysWithValues: inlinePinnedOrder.enumerated().map { ($1, $0) }
        )
        return pinnedFriends.sorted {
            positions[$0.member.id ?? -1, default: .max]
                < positions[$1.member.id ?? -1, default: .max]
        }
    }

    private var displayedFriends: [DashboardFriendDetailDTO] {
        displayedPinnedFriends + viewModel.sortedFriends.filter { $0.pinOrder == nil }
    }

    private func canReorder(_ friend: DashboardFriendDetailDTO) -> Bool {
        friend.pinOrder != nil && pinnedFriends.count >= 2
    }

    /// The slot the held card currently occupies. Only a drag has a slot, so an
    /// accessibility move — and the inline order being dropped once a save
    /// settles — rewrite `inlinePinnedOrder` without ticking.
    private var pinnedDragRetargetSlot: Int? {
        guard let draggedPinnedFriendID, let inlinePinnedOrder else { return nil }
        return inlinePinnedOrder.firstIndex(of: draggedPinnedFriendID)
    }

    /// Home only marks the card actions as suppressed on the iOS 18 lift, where
    /// the recognizer reports a distinct `began`. The iOS 17 fallback has no lift
    /// event of its own, so it keeps its historical behaviour of dragging without
    /// arming the suppression flag.
    private func pinnedFriendReorderGesture(
        _ friend: DashboardFriendDetailDTO
    ) -> DPPinnedFriendReorderGesture {
        DPPinnedFriendReorderGesture(
            isEnabled: canReorder(friend),
            coordinateSpaceName: HomePinnedFriendDragCoordinateSpace.name,
            onPressBegan: {
                guard let memberID = friend.member.id else { return }
                pressedPinnedFriendID = memberID
            },
            onPressEnded: {
                // Only this card may end its own press: a late ending from a card
                // released moments ago must not empty a ring that has since
                // started filling somewhere else.
                guard pressedPinnedFriendID == friend.member.id else { return }
                pressedPinnedFriendID = nil
            },
            onBegan: { location in
                guard let memberID = friend.member.id else { return }
                suppressFriendCardActions = true
                updatePinnedFriendDrag(memberID: memberID, location: location)
            },
            onChanged: { location in
                guard let memberID = friend.member.id else { return }
                updatePinnedFriendDrag(memberID: memberID, location: location)
            },
            onEnded: { location in
                if let location, let memberID = friend.member.id {
                    updatePinnedFriendDrag(memberID: memberID, location: location)
                }
                finishPinnedFriendDrag()
                releaseFriendCardActionSuppression()
            },
            onCancelled: {
                clearPinnedFriendDrag()
                releaseFriendCardActionSuppression()
            }
        )
    }

    private func releaseFriendCardActionSuppression() {
        DispatchQueue.main.async {
            suppressFriendCardActions = false
        }
    }

    private func updatePinnedFriendDrag(memberID: MemberID, location: CGPoint) {
        guard !isSavingPinnedOrder else { return }
        if draggedPinnedFriendID != memberID {
            let ids = displayedPinnedFriends.compactMap(\.member.id)
            inlinePinnedOrder = ids
            draggedPinnedFriendID = memberID
            pinnedDragOriginalOrder = ids
            pinnedDragReferenceTargets = pinnedFriendDropTargets.sorted { $0.frame.minY < $1.frame.minY }
            if let frame = pinnedFriendDropTargets.last(where: { $0.memberID == memberID })?.frame {
                pinnedDragPreviewSize = frame.size
                pinnedDragGrabOffset = CGSize(
                    width: location.x - frame.midX,
                    height: location.y - frame.midY
                )
            }
        }
        guard let previewSize = pinnedDragPreviewSize,
              let grabOffset = pinnedDragGrabOffset,
              !pinnedDragOriginalOrder.isEmpty else { return }

        pinnedDragLocation = location
        let previewFrame = CGRect(
            x: location.x - grabOffset.width - previewSize.width / 2,
            y: location.y - grabOffset.height - previewSize.height / 2,
            width: previewSize.width,
            height: previewSize.height
        )
        let nextOrder = DPPinnedFriendLiveOrder.reordered(
            pinnedDragOriginalOrder,
            draggedID: memberID,
            previewFrame: previewFrame,
            targets: pinnedDragReferenceTargets
        )
        guard nextOrder != inlinePinnedOrder else { return }
        withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
            inlinePinnedOrder = nextOrder
        }
    }

    private func finishPinnedFriendDrag() {
        let finalOrder = inlinePinnedOrder
        clearPinnedFriendDrag()
        guard let finalOrder,
              finalOrder != pinnedFriends.compactMap(\.member.id) else {
            inlinePinnedOrder = nil
            return
        }
        savePinnedOrder(finalOrder)
    }

    private func movePinnedFriend(_ friend: DashboardFriendDetailDTO, offset: Int) {
        guard canReorder(friend),
              !isSavingPinnedOrder,
              let memberID = friend.member.id else { return }
        var ids = displayedPinnedFriends.compactMap(\.member.id)
        guard let sourceIndex = ids.firstIndex(of: memberID) else { return }
        let destinationIndex = sourceIndex + offset
        guard ids.indices.contains(destinationIndex) else { return }
        ids.remove(at: sourceIndex)
        ids.insert(memberID, at: destinationIndex)
        withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
            inlinePinnedOrder = ids
        }
        savePinnedOrder(ids)
    }

    private func savePinnedOrder(_ memberIDs: [MemberID]) {
        guard !isSavingPinnedOrder else { return }
        let previousDashboard = viewModel.friendsDashboard
        viewModel.setPinnedFriendOrder(memberIDs)
        isSavingPinnedOrder = true
#if DEBUG
        if isUITesting {
            isSavingPinnedOrder = false
            inlinePinnedOrder = nil
            return
        }
#endif
        Task {
            do {
                try await pinRepository.updatePinnedOrder(memberIDs)
                await viewModel.retryFriendsDashboard()
            } catch {
                viewModel.replaceFriendsDashboardForMutation(previousDashboard)
                showsPinnedOrderError = true
            }
            isSavingPinnedOrder = false
            withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
                inlinePinnedOrder = nil
            }
        }
    }

    private func clearPinnedFriendDrag() {
        draggedPinnedFriendID = nil
        pinnedDragLocation = nil
        pinnedDragPreviewSize = nil
        pinnedDragGrabOffset = nil
        pinnedDragReferenceTargets = []
        pinnedDragOriginalOrder = []
    }

    private func togglePin(_ friend: DashboardFriendDetailDTO) async {
        guard pinningMemberID == nil,
              !isSavingPinnedOrder,
              draggedPinnedFriendID == nil,
              let memberID = friend.member.id else { return }
        pinningMemberID = memberID
        defer { pinningMemberID = nil }
        let previousDashboard = viewModel.friendsDashboard
        let isPinning = friend.pinOrder == nil
        viewModel.setFriendPinned(memberID: memberID, isPinned: isPinning)
#if DEBUG
        if isUITesting { return }
#endif
        do {
            if isPinning {
                try await pinRepository.pin(memberID)
            } else {
                try await pinRepository.unpin(memberID)
            }
            await viewModel.retryFriendsDashboard()
        } catch {
            viewModel.replaceFriendsDashboardForMutation(previousDashboard)
        }
    }

#if DEBUG
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated")
    }
#endif
}

private struct HomeScheduleRow: View {
    let schedule: ScheduleDTO

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
            Text(schedule.homeDisplayContent)
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: DPSpacing.small)
            if let time = schedule.displayTime {
                Text(time)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct FriendSummaryCard: View {
    let friend: DashboardFriendDetailDTO
    let isPinning: Bool
    let isDragPreview: Bool
    let openCalendar: () -> Void
    let togglePin: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            HomeAvatar(
                memberId: friend.member.id,
                name: friend.member.name,
                hasProfilePhoto: friend.member.hasProfilePhoto,
                profilePhotoVersion: friend.member.profilePhotoVersion,
                size: 64
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(friend.member.name)
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        if friend.isFamily {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DPColor.warning)
                                .accessibilityLabel(Text("home.family", tableName: "Home"))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: DPSize.minimumTouchTarget)

                HStack(spacing: 6) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 14))
                        .foregroundStyle(DPColor.textMuted)
                    Text("home.duty", tableName: "Home")
                        .foregroundStyle(DPColor.textSecondary)
                    if let duty = friend.duty {
                        Text(duty.displayName)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("-")
                            .foregroundStyle(DPColor.textMuted)
                    }
                }
                .font(DPTypography.caption)

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    ForEach(friend.schedules.prefix(2), id: \.id) { schedule in
                        Text(schedule.homeDisplayContent)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, DPSpacing.extraSmall)
                    }
                    if friend.schedules.count > 2 {
                        HStack(spacing: DPSpacing.extraSmall) {
                            Text("+\(friend.schedules.count - 2)")
                            Text("home.moreSchedules", tableName: "Home")
                        }
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .padding(.leading, DPSpacing.extraSmall)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DPSpacing.compact)
        .padding(.trailing, DPSize.minimumTouchTarget)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openCalendar)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.friend.\(friend.member.id ?? -1)")
        .background {
            if friend.pinOrder == nil {
                DPColor.backgroundCard
            } else {
                LinearGradient(
                    colors: [DPColor.backgroundSecondary, DPColor.backgroundTertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: friend.pinOrder == nil ? 1 : 2)
        }
        .overlay(alignment: .topTrailing) {
            if !isDragPreview {
                Button {
                    togglePin()
                } label: {
                    Group {
                        if isPinning {
                            ProgressView()
                                .tint(DPColor.textMuted)
                        } else {
                            Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
                        }
                    }
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPinning)
                .accessibilityLabel(
                    Text(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin", tableName: "Social")
                )
                .accessibilityIdentifier("home.friend.\(friend.member.id ?? -1).pin")
                .padding(.top, DPSpacing.compact)
                .padding(.trailing, DPSpacing.small)
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .accessibilityHint(Text("home.openCalendar", tableName: "Home"))
    }
}

private struct DutyBadge: View {
    let duty: DutyDTO

    var body: some View {
        Text(duty.displayName)
            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(parsedColor?.isLight == true ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(parsedColor?.color ?? DPColor.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
    }

    private var parsedColor: HomeHexColor? {
        HomeHexColor(duty.dutyColor)
    }
}

private struct HomeAvatar: View {
    let memberId: MemberID?
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let size: CGFloat

    var body: some View {
        Group {
            if hasProfilePhoto, let url = photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(DPColor.backgroundTertiary)
        .clipShape(Circle())
        .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 2) }
        .accessibilityLabel(name)
    }

    private var fallback: some View {
        Image(systemName: "person")
            .resizable()
            .scaledToFit()
            .padding(size * 0.25)
            .foregroundStyle(DPColor.textMuted)
    }

    private var photoURL: URL? {
        guard let memberId else { return nil }
        var components = URLComponents(
            url: AppConfiguration.apiBaseURL.appending(path: "members/\(memberId)/profile-photo"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: String(profilePhotoVersion))
        ]
        return components?.url
    }
}

private struct HomeHexColor {
    let red: Int
    let green: Int
    let blue: Int

    init?(_ value: String?) {
        guard var value else { return nil }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
        red = (rgb >> 16) & 0xFF
        green = (rgb >> 8) & 0xFF
        blue = rgb & 0xFF
    }

    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    var isLight: Bool {
        (red * 299 + green * 587 + blue * 114) > 186_000
    }
}

private extension ScheduleDTO {
    var homeDisplayContent: String {
        var text = content
        if totalDays > 1 {
            text += " [\(daysFromStart)/\(totalDays)]"
        }
        if isTagged {
            text += " (by \(owner))"
        }
        return text
    }

    var displayTime: String? {
        let value = startDateTime.rawValue
        guard value.count >= 16,
              String(value.prefix(10)) == curDate.rawValue
        else {
            return nil
        }
        let start = value.index(value.startIndex, offsetBy: 11)
        let end = value.index(start, offsetBy: 5)
        let time = String(value[start..<end])
        return time == "00:00" ? nil : time
    }
}

private extension DutyDTO {
    var displayName: String {
        guard let dutyType, !dutyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return homeLocalized("home.offDuty")
        }
        return dutyType
    }
}

private enum HomePinnedFriendDragCoordinateSpace {
    static let name = "home-pinned-friend-drag"
}

private extension View {
    func homeCard() -> some View {
        background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                    .stroke(DPColor.borderPrimary)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }
}

private struct HomePanelHeaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
