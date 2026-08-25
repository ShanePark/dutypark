import SwiftUI

func homeLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Home", locale: locale)
}

/// Geometry and text slots for one portrait card in the home friend rail.
///
/// The rail is the same card rail as the friend tag selector, so the width comes
/// from that component's own 3.2-way split instead of a second formula. The team
/// and duty lines always carry text: a friend with no team and no duty has to end
/// up with a card of exactly the same height as everyone else.
enum HomeFriendCardLayout {
    static let minimumCardWidth = DPFriendTagSelectionLogic.minimumCardWidth
    static let maximumCardWidth = DPFriendTagSelectionLogic.maximumCardWidth
    /// Leading and trailing inset of the rail's content, so a card can peek out
    /// from under the panel edge instead of stopping short of it.
    static let railInset = DPSpacing.medium
    /// Reserves the line box for a friend without a team. Rendering nothing would
    /// shorten the card, and a written placeholder would read as a team name.
    static let blankLine = " "
    static let missingDuty = "-"
    static let dragAutoScrollDuration: TimeInterval = 0.24
    static let dragAutoScrollInterval = Duration.milliseconds(280)

    static func cardWidth(
        availableWidth: CGFloat,
        spacing: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        DPFriendTagSelectionLogic.cardWidth(
            availableWidth: availableWidth,
            spacing: spacing,
            minimum: minimum,
            maximum: maximum
        )
    }

    static func teamLine(for team: String?) -> String {
        guard let team, !team.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return blankLine
        }
        return team
    }

    static func dutyLine(for duty: DutyDTO?, locale: Locale? = nil) -> String {
        guard let duty else { return missingDuty }
        guard let dutyType = duty.dutyType,
              !dutyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return homeLocalized("home.offDuty", locale: locale)
        }
        return dutyType
    }
}

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var pendingUnpinConfirmation: HomeUnpinConfirmation?
    @State private var pinningMemberID: MemberID?
    @State private var inlinePinnedOrder: [MemberID]?
    @State private var draggedPinnedFriendID: MemberID?
    /// The card currently under the finger, used only by the press progress ring.
    @State private var pressedPinnedFriendID: MemberID?
    @State private var pinnedDragLocation: CGPoint?
    @State private var pinnedDragInitialLocation: CGPoint?
    @State private var pinnedDragPreviewSize: CGSize?
    @State private var pinnedDragGrabOffset: CGSize?
    @State private var pinnedFriendDropTargets: [DPPinnedFriendDropTarget] = []
    @State private var pinnedDragReferenceTargets: [DPPinnedFriendDropTarget] = []
    @State private var pinnedDragOriginalOrder: [MemberID] = []
    @State private var pinnedFriendRailViewport: CGRect = .zero
    @State private var pinnedDragAutoScrollDirection: HomeFriendRailAutoScrollDirection?
    @State private var pinnedDragAutoScrollTask: Task<Void, Never>?
    @State private var dragSuppressedFriendID: MemberID?
    @State private var isSavingPinnedOrder = false
    @State private var showsPinnedOrderError = false
    @State private var railWidth: CGFloat = 0
    /// The rail sizes its cards from the width it actually gets, between these bounds.
    @ScaledMetric(relativeTo: .subheadline) private var minimumCardWidth = HomeFriendCardLayout.minimumCardWidth
    @ScaledMetric(relativeTo: .subheadline) private var maximumCardWidth = HomeFriendCardLayout.maximumCardWidth
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
        .coordinateSpace(name: HomeFriendDragCoordinateSpace.name)
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
               let friend = displayedPinnedFriends.first(where: { $0.member.id == draggedPinnedFriendID }) {
                HomeFriendCard(
                    friend: friend,
                    isPinning: false,
                    isDragPreview: true,
                    width: pinnedDragPreviewSize.width,
                    openCalendar: {},
                    togglePin: {},
                    consumeDragSuppression: { false }
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
        .alert(item: $pendingUnpinConfirmation) { confirmation in
            Alert(
                title: Text(social("social.confirm.unpin.title")),
                message: Text(socialFormat("social.confirm.unpin.message", confirmation.friend.member.name)),
                primaryButton: .destructive(Text(social("social.action.unpin"))) {
                    Task { await togglePin(confirmation.friend) }
                },
                secondaryButton: .cancel(Text(social("social.action.cancelDialog")))
            )
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
            Button {
                DPHapticCenter.shared.emit(.routine)
                onRoute(.friends)
            } label: {
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

    @ViewBuilder
    private var friendsDashboardContent: some View {
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
            .padding(20)
            .accessibilityIdentifier("home.friends.empty")
        } else {
            friendsRail
                .padding(.vertical, DPSpacing.medium)
        }
    }

    private var pinnedFriends: [DashboardFriendDetailDTO] {
        viewModel.sortedFriends.filter { $0.pinOrder != nil }
    }

    private var displayedPinnedFriends: [DashboardFriendDetailDTO] {
        let friends = pinnedFriends
        guard let inlinePinnedOrder else { return friends }
        let positions = Dictionary(
            uniqueKeysWithValues: inlinePinnedOrder.enumerated().map { ($1, $0) }
        )
        return friends.sorted {
            positions[$0.member.id ?? -1, default: .max]
                < positions[$1.member.id ?? -1, default: .max]
        }
    }

    /// Pinned friends first, then the rest. Only pinned friends are reorderable.
    private var displayedFriends: [DashboardFriendDetailDTO] {
        displayedPinnedFriends + viewModel.sortedFriends.filter { $0.pinOrder == nil }
    }

    private var friendsRail: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DPSpacing.small) {
                    ForEach(displayedFriends, id: \.member.id) { friend in
                        HomeFriendCard(
                            friend: friend,
                            isPinning: pinningMemberID == friend.member.id,
                            isDragPreview: false,
                            width: cardWidth,
                            openCalendar: { openCalendar(for: friend.member.id) },
                            togglePin: { requestTogglePin(friend) },
                            consumeDragSuppression: {
                                consumeDragSuppression(for: friend.member.id)
                            }
                        )
                        .id(friend.member.id ?? -1)
                        .dpDragSourceSlot(
                            isLifted: draggedPinnedFriendID == friend.member.id,
                            tint: DPColor.accent,
                            cornerRadius: DPRadius.large
                        )
                        .background {
                            if friend.pinOrder != nil,
                               let memberID = friend.member.id {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: DPPinnedFriendDropTargetPreferenceKey.self,
                                        value: [DPPinnedFriendDropTarget(
                                            memberID: memberID,
                                            frame: proxy.frame(in: .named(HomeFriendDragCoordinateSpace.name))
                                        )]
                                    )
                                }
                            }
                        }
                        .modifier(pinnedFriendReorderGesture(friend) { memberID, direction in
                            withAnimation(.smooth(
                                duration: HomeFriendCardLayout.dragAutoScrollDuration,
                                extraBounce: 0
                            )) {
                                scrollProxy.scrollTo(
                                    memberID,
                                    anchor: direction == .forward ? .trailing : .leading
                                )
                            }
                        })
                        .dpPressProgress(
                            isPressing: pressedPinnedFriendID == friend.member.id,
                            isDragging: draggedPinnedFriendID == friend.member.id,
                            tint: DPColor.accent
                        )
                        .accessibilityActions {
                            ForEach(accessiblePinnedFriendMoves(friend), id: \.offset) { move in
                                Button(homeLocalized(move.key)) {
                                    guard let memberID = friend.member.id else { return }
                                    movePinnedFriend(memberID: memberID, to: move.destinationIndex)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, HomeFriendCardLayout.railInset)
            }
            // The outer page lock is not enough once this rail's pan recognizer
            // has already started. Freeze direct pan input after lift; edge
            // auto-scroll below remains programmatic.
            .scrollDisabled(draggedPinnedFriendID != nil)
            .background {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named(HomeFriendDragCoordinateSpace.name))
                    Color.clear
                        .onAppear {
                            railWidth = proxy.size.width
                            pinnedFriendRailViewport = frame
                        }
                        .onChange(of: frame) { _, nextFrame in
                            railWidth = nextFrame.width
                            pinnedFriendRailViewport = nextFrame
                        }
                }
            }
        }
    }

    private var cardWidth: CGFloat {
        guard railWidth > 0 else { return minimumCardWidth }
        return HomeFriendCardLayout.cardWidth(
            availableWidth: railWidth - HomeFriendCardLayout.railInset * 2,
            spacing: DPSpacing.small,
            minimum: minimumCardWidth,
            maximum: maximumCardWidth
        )
    }

    private var pinnedDragRetargetSlot: Int? {
        guard let draggedPinnedFriendID, let inlinePinnedOrder else { return nil }
        return inlinePinnedOrder.firstIndex(of: draggedPinnedFriendID)
    }

    private func isPinnedFriendReorderEnabled(
        _ friend: DashboardFriendDetailDTO
    ) -> Bool {
        !isSavingPinnedOrder
            && pinningMemberID == nil
            && friend.pinOrder != nil
            && pinnedFriends.count >= 2
    }

    private func accessiblePinnedFriendMoves(
        _ friend: DashboardFriendDetailDTO
    ) -> [HomePinnedFriendAccessibleMove] {
        guard isPinnedFriendReorderEnabled(friend),
              let memberID = friend.member.id else { return [] }
        let pinnedIDs = displayedPinnedFriends.compactMap(\.member.id)
        guard let index = pinnedIDs.firstIndex(of: memberID) else { return [] }

        var moves: [HomePinnedFriendAccessibleMove] = []
        if index > 0 {
            moves.append(.init(offset: -1, destinationIndex: index - 1, key: "home.action.moveUp"))
        }
        if index < pinnedIDs.count - 1 {
            moves.append(.init(offset: 1, destinationIndex: index + 1, key: "home.action.moveDown"))
        }
        return moves
    }

    private func pinnedFriendReorderGesture(
        _ friend: DashboardFriendDetailDTO,
        scrollTo: @escaping (MemberID, HomeFriendRailAutoScrollDirection) -> Void
    ) -> DPPinnedFriendReorderGesture {
        DPPinnedFriendReorderGesture(
            isEnabled: isPinnedFriendReorderEnabled(friend),
            coordinateSpaceName: HomeFriendDragCoordinateSpace.name,
            onPressBegan: {
                guard let memberID = friend.member.id else { return }
                pressedPinnedFriendID = memberID
            },
            onPressEnded: {
                guard pressedPinnedFriendID == friend.member.id else { return }
                pressedPinnedFriendID = nil
            },
            onBegan: { location in
                guard let memberID = friend.member.id else { return }
                updatePinnedFriendDrag(memberID: memberID, location: location, scrollTo: scrollTo)
            },
            onChanged: { location in
                guard let memberID = friend.member.id else { return }
                updatePinnedFriendDrag(memberID: memberID, location: location, scrollTo: scrollTo)
            },
            onEnded: { _ in finishPinnedFriendDrag() },
            onCancelled: {
                guard let memberID = friend.member.id else { return }
                cancelPinnedFriendDrag(memberID)
            }
        )
    }

    private func cancelPinnedFriendDrag(_ memberID: MemberID) {
        guard draggedPinnedFriendID == memberID else { return }
        clearPinnedFriendDrag()
        scheduleDragSuppressionReset(for: memberID)
    }

    /// A completed drag can otherwise be interpreted as the tap that opens the
    /// friend's calendar or toggles its pin state.
    private func consumeDragSuppression(for memberID: MemberID?) -> Bool {
        guard let memberID, dragSuppressedFriendID == memberID else { return false }
        dragSuppressedFriendID = nil
        return true
    }

    private func scheduleDragSuppressionReset(for memberID: MemberID) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            if dragSuppressedFriendID == memberID {
                dragSuppressedFriendID = nil
            }
        }
    }

    private func updatePinnedFriendDrag(
        memberID: MemberID,
        location: CGPoint,
        scrollTo: @escaping (MemberID, HomeFriendRailAutoScrollDirection) -> Void
    ) {
        guard !isSavingPinnedOrder else { return }
        if draggedPinnedFriendID != memberID {
            let ids = displayedPinnedFriends.compactMap(\.member.id)
            guard ids.contains(memberID) else { return }
            inlinePinnedOrder = ids
            draggedPinnedFriendID = memberID
            dragSuppressedFriendID = memberID
            pinnedDragInitialLocation = location
            pinnedDragOriginalOrder = ids
            if let frame = pinnedFriendDropTargets.last(where: { $0.memberID == memberID })?.frame {
                pinnedDragPreviewSize = frame.size
                pinnedDragGrabOffset = CGSize(
                    width: location.x - frame.midX,
                    height: location.y - frame.midY
                )
                pinnedDragReferenceTargets = referenceTargets(
                    order: ids,
                    draggedID: memberID,
                    sourceFrame: frame
                )
            }
        }
        guard let previewSize = pinnedDragPreviewSize,
              let grabOffset = pinnedDragGrabOffset,
              !pinnedDragOriginalOrder.isEmpty else { return }

        pinnedDragLocation = location
        let previewFrame = pinnedFriendPreviewFrame(
            location: location,
            previewSize: previewSize,
            grabOffset: grabOffset
        )
        let autoScrollDirection = pinnedDragInitialLocation.flatMap { initialLocation in
            HomeFriendRailDragPolicy.autoScrollDirection(
                location: location,
                initialLocation: initialLocation,
                viewport: pinnedFriendRailViewport,
                minimumMovement: DPPinnedFriendDragLayout.activationDistance
            )
        }
        updatePinnedFriendAutoScroll(
            direction: autoScrollDirection,
            memberID: memberID,
            scrollTo: scrollTo
        )
        guard autoScrollDirection == nil else { return }

        let nextOrder = DPPinnedFriendLiveOrder.reordered(
            pinnedDragOriginalOrder,
            draggedID: memberID,
            previewFrame: previewFrame,
            axis: .horizontal,
            targets: pinnedDragReferenceTargets
        )
        guard nextOrder != inlinePinnedOrder else { return }
        withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
            inlinePinnedOrder = nextOrder
        }
    }

    private func updatePinnedFriendAutoScroll(
        direction: HomeFriendRailAutoScrollDirection?,
        memberID: MemberID,
        scrollTo: @escaping (MemberID, HomeFriendRailAutoScrollDirection) -> Void
    ) {
        guard direction != pinnedDragAutoScrollDirection else { return }
        pinnedDragAutoScrollTask?.cancel()
        pinnedDragAutoScrollTask = nil
        pinnedDragAutoScrollDirection = direction

        guard let direction else {
            rebasePinnedFriendDrag(memberID: memberID)
            return
        }

        pinnedDragAutoScrollTask = Task { @MainActor in
            while !Task.isCancelled,
                  draggedPinnedFriendID == memberID,
                  pinnedDragAutoScrollDirection == direction {
                let currentOrder = inlinePinnedOrder ?? displayedPinnedFriends.compactMap(\.member.id)
                let nextOrder = HomeFriendRailDragPolicy.movedOrder(
                    currentOrder,
                    draggedID: memberID,
                    direction: direction
                )
                guard nextOrder != currentOrder else { break }

                withAnimation(.smooth(
                    duration: HomeFriendCardLayout.dragAutoScrollDuration,
                    extraBounce: 0
                )) {
                    inlinePinnedOrder = nextOrder
                }
                rebasePinnedFriendDrag(memberID: memberID)
                await Task.yield()
                guard !Task.isCancelled else { break }
                scrollTo(memberID, direction)

                try? await Task.sleep(for: HomeFriendCardLayout.dragAutoScrollInterval)
            }

            if pinnedDragAutoScrollDirection == direction {
                pinnedDragAutoScrollTask = nil
            }
        }
    }

    private func rebasePinnedFriendDrag(memberID: MemberID) {
        guard let previewFrame = currentPinnedFriendPreviewFrame() else { return }
        let order = inlinePinnedOrder ?? displayedPinnedFriends.compactMap(\.member.id)
        pinnedDragOriginalOrder = order
        pinnedDragReferenceTargets = referenceTargets(
            order: order,
            draggedID: memberID,
            sourceFrame: previewFrame
        )
    }

    private func referenceTargets(
        order: [MemberID],
        draggedID: MemberID,
        sourceFrame: CGRect
    ) -> [DPPinnedFriendDropTarget] {
        HomeFriendRailDragPolicy.referenceFrames(
            order: order,
            draggedID: draggedID,
            sourceFrame: sourceFrame,
            spacing: DPSpacing.small
        )
        .map { DPPinnedFriendDropTarget(memberID: $0.key, frame: $0.value) }
    }

    private func pinnedFriendPreviewFrame(
        location: CGPoint,
        previewSize: CGSize,
        grabOffset: CGSize
    ) -> CGRect {
        CGRect(
            x: location.x - grabOffset.width - previewSize.width / 2,
            y: location.y - grabOffset.height - previewSize.height / 2,
            width: previewSize.width,
            height: previewSize.height
        )
    }

    private func currentPinnedFriendPreviewFrame() -> CGRect? {
        guard let location = pinnedDragLocation,
              let previewSize = pinnedDragPreviewSize,
              let grabOffset = pinnedDragGrabOffset else { return nil }
        return pinnedFriendPreviewFrame(
            location: location,
            previewSize: previewSize,
            grabOffset: grabOffset
        )
    }

    private func finishPinnedFriendDrag() {
        let memberID = draggedPinnedFriendID
        let finalOrder = inlinePinnedOrder
        clearPinnedFriendDrag()
        if let memberID {
            scheduleDragSuppressionReset(for: memberID)
        }
        guard let finalOrder,
              finalOrder != pinnedFriends.compactMap(\.member.id) else {
            inlinePinnedOrder = nil
            return
        }
        savePinnedOrder(finalOrder)
    }

    private func movePinnedFriend(memberID: MemberID, to destinationIndex: Int) {
        guard !isSavingPinnedOrder else { return }
        var ids = displayedPinnedFriends.compactMap(\.member.id)
        guard let sourceIndex = ids.firstIndex(of: memberID), sourceIndex != destinationIndex else { return }
        ids.remove(at: sourceIndex)
        ids.insert(memberID, at: min(max(0, destinationIndex), ids.count))
        withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
            inlinePinnedOrder = ids
        }
        savePinnedOrder(ids)
    }

    private func savePinnedOrder(_ memberIDs: [MemberID]) {
        guard !isSavingPinnedOrder else { return }
        let currentIDs = pinnedFriends.compactMap(\.member.id)
        guard memberIDs.count == currentIDs.count,
              Set(memberIDs) == Set(currentIDs) else {
            inlinePinnedOrder = nil
            return
        }

        let previousDashboard = viewModel.friendsDashboard
        viewModel.setPinnedFriendOrder(memberIDs)
        isSavingPinnedOrder = true
        Task { @MainActor in
            defer { isSavingPinnedOrder = false }
#if DEBUG
            if isUITesting {
                withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
                    inlinePinnedOrder = nil
                }
                return
            }
#endif
            do {
                try await pinRepository.updatePinnedOrder(memberIDs)
                DPHapticCenter.shared.emit(.success)
            } catch {
                viewModel.replaceFriendsDashboardForMutation(previousDashboard)
                showsPinnedOrderError = true
                DPHapticCenter.shared.emit(.error)
            }
            withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
                inlinePinnedOrder = nil
            }
        }
    }

    private func clearPinnedFriendDrag() {
        pinnedDragAutoScrollTask?.cancel()
        pinnedDragAutoScrollTask = nil
        pinnedDragAutoScrollDirection = nil
        draggedPinnedFriendID = nil
        pinnedDragLocation = nil
        pinnedDragInitialLocation = nil
        pinnedDragPreviewSize = nil
        pinnedDragGrabOffset = nil
        pinnedDragReferenceTargets = []
        pinnedDragOriginalOrder = []
        pressedPinnedFriendID = nil
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
        DPHapticCenter.shared.emit(.routine)
        onRoute(.memberCalendar(memberId))
    }

    private func requestTogglePin(_ friend: DashboardFriendDetailDTO) {
        guard pinningMemberID == nil,
              !isSavingPinnedOrder,
              draggedPinnedFriendID == nil else { return }
        if friend.pinOrder == nil {
            DPHapticCenter.shared.emit(.selection)
            Task { await togglePin(friend) }
        } else {
            pendingUnpinConfirmation = HomeUnpinConfirmation(friend: friend)
        }
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
            // The endpoint is the mutation boundary. Refreshing the rail
            // below is reconciliation and must not replace this success
            // event with a second or misleading result.
            DPHapticCenter.shared.emit(.success)
            await viewModel.retryFriendsDashboard()
        } catch {
            viewModel.replaceFriendsDashboardForMutation(previousDashboard)
            DPHapticCenter.shared.emit(.error)
        }
    }

#if DEBUG
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated")
    }
#endif
}

private struct HomeUnpinConfirmation: Identifiable {
    let friend: DashboardFriendDetailDTO

    var id: MemberID { friend.member.id ?? -1 }
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

/// One portrait card in the home friend rail, shaped like the friend tag
/// selector's card: a 3:4 photo, the name, the team line and today's duty badge.
/// The last two lines always render text so a friend without a team, or without a
/// duty, still produces a card of exactly the same height.
private struct HomeFriendCard: View {
    let friend: DashboardFriendDetailDTO
    let isPinning: Bool
    let isDragPreview: Bool
    let width: CGFloat
    let openCalendar: () -> Void
    let togglePin: () -> Void
    let consumeDragSuppression: () -> Bool

    private var portraitWidth: CGFloat { width - DPSpacing.small }
    private var portraitHeight: CGFloat { portraitWidth * 4 / 3 }

    var body: some View {
        VStack(spacing: DPSpacing.extraSmall) {
            portrait

            // No `minimumScaleFactor` on any line of the card: a shrunk `Text`
            // also shrinks its line box, which would make a long name or team
            // name produce a shorter card. Truncation keeps every line the
            // exact same height.
            Text(friend.member.name)
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Text(HomeFriendCardLayout.teamLine(for: friend.member.team))
                .font(DPFont.light(size: 10, relativeTo: .caption2))
                .foregroundStyle(DPColor.textMuted)
                .lineLimit(1)

            HomeFriendDutyBadge(duty: friend.duty)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DPSpacing.extraSmall)
        .frame(width: width)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !consumeDragSuppression() else { return }
            openCalendar()
        }
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
                pinButton
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .accessibilityHint(Text("home.openCalendar", tableName: "Home"))
    }

    private var portrait: some View {
        DPProfileAvatar(
            memberID: friend.member.id,
            profilePhotoVersion: friend.member.profilePhotoVersion,
            size: CGSize(width: portraitWidth, height: portraitHeight),
            shape: .roundedRectangle(cornerRadius: DPRadius.standard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
        .overlay(alignment: .topLeading) {
            if friend.isFamily {
                Image(systemName: "house.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DPColor.warning)
                    .frame(width: 18, height: 18)
                    .background(DPColor.backgroundCard.opacity(0.9), in: Circle())
                    .padding(3)
                    .accessibilityLabel(Text("home.family", tableName: "Home"))
            }
        }
    }

    /// The star sits on a card only 60–88pt wide, so the visible chip stays small
    /// while its touch target grows inwards from the corner to the full 44pt. The
    /// rest of the card keeps opening the friend's calendar.
    private var pinButton: some View {
        Button {
            guard !consumeDragSuppression() else { return }
            togglePin()
        } label: {
            pinGlyph
                .frame(width: 26, height: 26)
                .background(DPColor.backgroundCard.opacity(0.9), in: Circle())
                .overlay { Circle().stroke(DPColor.borderPrimary) }
                .padding(
                    EdgeInsets(
                        top: 4,
                        leading: DPSize.minimumTouchTarget - 30,
                        bottom: DPSize.minimumTouchTarget - 30,
                        trailing: 4
                    )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPinning)
        .accessibilityLabel(
            Text(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin", tableName: "Social")
        )
        .accessibilityIdentifier("home.friend.\(friend.member.id ?? -1).pin")
    }

    @ViewBuilder
    private var pinGlyph: some View {
        if isPinning {
            ProgressView()
                .controlSize(.mini)
                .tint(DPColor.textMuted)
        } else {
            Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
        }
    }
}

/// Today's duty for one friend. A friend with no duty at all still gets a badge —
/// a dash — so the line keeps its slot and every card stays the same height.
private struct HomeFriendDutyBadge: View {
    let duty: DutyDTO?

    var body: some View {
        Text(HomeFriendCardLayout.dutyLine(for: duty))
            .font(DPFont.bold(size: 10, relativeTo: .caption2))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
            .accessibilityLabel(
                Text("home.duty", tableName: "Home")
                    + Text(" \(HomeFriendCardLayout.dutyLine(for: duty))")
            )
    }

    private var parsedColor: HomeHexColor? {
        duty.flatMap { HomeHexColor($0.dutyColor) }
    }

    private var background: Color {
        guard duty != nil else { return DPColor.backgroundTertiary }
        return parsedColor?.color ?? DPColor.textMuted
    }

    private var foreground: Color {
        guard duty != nil else { return DPColor.textMuted }
        return parsedColor?.isLight == true ? Color.black : Color.white
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
    let profilePhotoVersion: Int64
    let size: CGFloat

    var body: some View {
        DPProfileAvatar(
            memberID: memberId,
            profilePhotoVersion: profilePhotoVersion,
            size: size
        )
        .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 2) }
        .accessibilityLabel(name)
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

private enum HomeFriendDragCoordinateSpace {
    static let name = "home-friend-drag"
}

private struct HomePinnedFriendAccessibleMove {
    let offset: Int
    let destinationIndex: Int
    let key: String
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
