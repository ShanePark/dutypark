import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel: SocialViewModel
    @State private var isSearchPresented = false
    @State private var isHelpPresented = false
    @State private var candidate: SearchCandidate?
    @State private var confirmation: SocialConfirmation?
    @State private var isPerformingConfirmation = false
    @State private var actionCandidate: ActionCandidate?
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
    @State private var dragSuppressedFriendID: MemberID?
    @State private var isSavingPinnedOrder = false

    private let onOpenCalendar: (MemberID) -> Void

    init(
        repository: any SocialRepository = LiveSocialRepository(),
        onMutation: @escaping @MainActor (Bool) async -> Void = { _ in },
        onOpenCalendar: @escaping (MemberID) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: SocialViewModel(repository: repository, onMutation: onMutation)
        )
        self.onOpenCalendar = onOpenCalendar
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.friends.isEmpty && !viewModel.hasPendingRequests {
                ProgressView(social("social.loading"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("social.loading")
            } else {
                friendContent
            }
        }
        .background(DPColor.backgroundSecondary.ignoresSafeArea())
        // The screen names itself once, in the navigation bar it is pushed under, and
        // hangs its actions there as well. Pushed from the dashboard that bar held a
        // back button and nothing else, while the content below repeated the name.
        .navigationTitle(social("social.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { headerActions }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .overlay {
            ZStack(alignment: .topLeading) {
                if let draggedPinnedFriendID,
                   let pinnedDragLocation,
                   let pinnedDragPreviewSize,
                   let pinnedDragGrabOffset,
                   let friend = displayedPinnedFriends.first(where: { $0.member.id == draggedPinnedFriendID }) {
                    friendCard(friend, isDragPreview: true)
                        .frame(width: pinnedDragPreviewSize.width, height: pinnedDragPreviewSize.height)
                        .dpDragLift(tint: DPColor.accent, cornerRadius: DPRadius.large)
                        .position(
                            x: pinnedDragLocation.x - pinnedDragGrabOffset.width,
                            y: pinnedDragLocation.y - pinnedDragGrabOffset.height
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
#if DEBUG
                if isSocialReorderUITesting {
                    uiTestingProbes
                }
#endif
            }
        }
        .fullScreenCover(isPresented: $isHelpPresented) {
            DPModalOverlay(onDismiss: { isHelpPresented = false }) { availableSize, dismiss in
                SocialHelpModal(maximumHeight: availableSize.height, dismiss: dismiss)
            }
        }
        .fullScreenCover(isPresented: $isSearchPresented) {
            DPModalOverlay(onDismiss: { isSearchPresented = false }) { availableSize, dismiss in
                FriendSearchModalView(
                    viewModel: viewModel,
                    availableSize: availableSize,
                    onSelectCandidate: { candidate = SearchCandidate(member: $0) },
                    onDismiss: dismiss
                )
                .alert(item: $candidate) { candidate in
                    Alert(
                        title: Text(social("social.confirm.sendFriend.title")),
                        message: Text(socialFormat("social.confirm.sendFriend.message", candidate.member.name)),
                        primaryButton: .default(Text(social("social.action.sendRequest"))) {
                            Task {
                                await viewModel.sendFriendRequest(to: candidate.member)
                                if viewModel.errorKey == nil { dismiss() }
                            }
                        },
                        secondaryButton: .cancel(Text(social("social.action.cancelDialog")))
                    )
                }
            }
        }
        .fullScreenCover(item: $confirmation) { confirmation in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { self.confirmation = nil },
                canDismiss: !isPerformingConfirmation
            ) { availableSize, dismiss in
                DPConfirmationPanel(
                    title: social(confirmation.titleKey),
                    message: socialFormat(confirmation.messageKey, confirmation.memberName),
                    confirmTitle: social(confirmation.confirmKey),
                    cancelTitle: social("social.action.cancelDialog"),
                    isDestructive: confirmation.isDestructive,
                    isWorking: isPerformingConfirmation,
                    maximumHeight: availableSize.height,
                    cancel: dismiss,
                    confirm: {
                        perform(confirmation, dismiss: dismiss)
                    }
                )
            }
            .interactiveDismissDisabled(isPerformingConfirmation)
        }
        .alert(
            social("social.error.title"),
            isPresented: Binding(
                get: { viewModel.errorKey != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(social("social.action.ok")) { viewModel.dismissError() }
        } message: {
            Text(social(viewModel.errorKey ?? "social.error.generic"))
        }
    }

    /// Applied to the mutating controls only. Disabling the whole screen would
    /// also tear down the pinned friend reorder gesture while a save is in flight.
    private var isMutationInFlight: Bool {
        viewModel.isPerformingAction || isSavingPinnedOrder
    }

    private var friendContent: some View {
        ScrollView {
            // The panels stack eagerly: the friend panel's own `LazyVStack` keeps
            // the rows lazy, while a lazy outer stack made the scroll content
            // height unstable once a panel followed the friend list, and the
            // pinned drop-target geometry then re-published forever.
            VStack(spacing: DPSpacing.large) {
                if viewModel.hasPendingRequests {
                    requestsPanel
                }

                friendsPanel

                BlockedMembersPanel(
                    members: viewModel.blockedMembers,
                    isDisabled: isMutationInFlight,
                    unblock: { member in
                        confirmation = .unblock(member)
                    }
                )
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.small)
            .padding(.bottom, DPSpacing.large)
        }
        .coordinateSpace(name: SocialFriendDragCoordinateSpace.name)
        .onPreferenceChange(DPPinnedFriendDropTargetPreferenceKey.self) {
            pinnedFriendDropTargets = $0
        }
        .scrollDisabled(draggedPinnedFriendID != nil)
        .dpDragFeedback(dragID: draggedPinnedFriendID)
        .dpDragRetargetFeedback(target: pinnedDragRetargetSlot)
        .accessibilityIdentifier("social.list")
    }

    // Help and add friend live in the navigation bar next to the screen's name, so
    // the list starts at the top of the content instead of under a header row that
    // said the same thing as the bar above it.
    @ToolbarContentBuilder
    private var headerActions: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            DPHelpButton(label: social("social.help.open")) {
                withoutPresentationAnimation { isHelpPresented = true }
            }
            .accessibilityIdentifier("social.help")

            Button {
                withoutPresentationAnimation { isSearchPresented = true }
            } label: {
                Image(systemName: "person.badge.plus")
                    .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(social("social.action.addFriend"))
            .accessibilityIdentifier("social.addFriend")
            .disabled(isMutationInFlight)
        }
    }

    private var requestsPanel: some View {
        VStack(spacing: 0) {
            SocialPanelHeader(
                title: social("social.section.requests"),
                count: viewModel.receivedRequests.count + viewModel.sentRequests.count,
                systemImage: "person.crop.circle.badge.checkmark",
                colors: [DPColor.warning, DPColor.warningHover]
            )

            LazyVStack(spacing: DPSpacing.compact) {
                ForEach(viewModel.receivedRequests, id: \.id) { request in
                    receivedRequestCard(request)
                }
                ForEach(viewModel.sentRequests, id: \.id) { request in
                    sentRequestCard(request)
                }
            }
            .padding(DPSpacing.medium)
            .disabled(isMutationInFlight)
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private var friendsPanel: some View {
        VStack(spacing: 0) {
            SocialPanelHeader(
                title: social("social.section.friends"),
                count: viewModel.friends.count,
                systemImage: "person.2",
                colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt]
            )

            LazyVStack(spacing: DPSpacing.small) {
                if viewModel.friends.isEmpty {
                    emptyFriends
                } else {
                    ForEach(displayedPinnedFriends, id: \.member.id) { friend in
                        friendCard(friend)
                    }
                    ForEach(viewModel.unpinnedFriends, id: \.member.id) { friend in
                        friendCard(friend)
                    }
                }

                addFriendCard
            }
            .padding(SocialFriendCardLayout.panelInset)
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private func receivedRequestCard(_ request: FriendRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            requestIdentity(
                member: request.fromMember,
                type: request.requestType,
                subtitle: requestTypeLabel(request.requestType)
            )

            HStack(spacing: DPSpacing.small) {
                Spacer(minLength: 0)

                compactActionButton(
                    social("social.action.accept"),
                    foreground: DPColor.textOnDark,
                    background: DPColor.success,
                    border: nil
                ) {
                    Task { await viewModel.accept(request) }
                }

                compactActionButton(
                    social("social.action.reject"),
                    foreground: DPColor.danger,
                    background: DPColor.backgroundCard,
                    border: DPColor.dangerBorder
                ) {
                    confirmation = .reject(request)
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(DPColor.accentBorder, lineWidth: 1)
        }
    }

    private func sentRequestCard(_ request: FriendRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            requestIdentity(
                member: request.toMember,
                type: request.requestType,
                subtitle: socialFormat("social.request.sent", requestTypeLabel(request.requestType))
            )

            HStack {
                Spacer(minLength: 0)
                compactActionButton(
                    social("social.action.cancel"),
                    foreground: DPColor.warningHover,
                    background: DPColor.backgroundCard,
                    border: DPColor.warningBorder
                ) {
                    confirmation = .cancel(request)
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(DPColor.warningBorder, lineWidth: 1)
        }
    }

    private func requestIdentity(
        member: MemberPreviewDTO,
        type: FriendRequestType,
        subtitle: String
    ) -> some View {
        HStack(spacing: DPSpacing.compact) {
            RequestAvatar(member: member, type: type)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(DPFont.bold(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func compactActionButton(
        _ title: String,
        foreground: Color,
        background: Color,
        border: Color?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DPFont.light(size: 14, relativeTo: .subheadline))
                .foregroundStyle(foreground)
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous))
                .overlay {
                    if let border {
                        RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var displayedPinnedFriends: [DashboardFriendDetailDTO] {
        let friends = viewModel.pinnedFriends
        guard let inlinePinnedOrder else { return friends }
        let positions = Dictionary(
            uniqueKeysWithValues: inlinePinnedOrder.enumerated().map { ($1, $0) }
        )
        return friends.sorted {
            positions[$0.member.id ?? -1, default: .max]
                < positions[$1.member.id ?? -1, default: .max]
        }
    }

    private func friendCard(
        _ friend: DashboardFriendDetailDTO,
        isDragPreview: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                guard let id = friend.member.id else { return }
                guard !consumeDragSuppression(for: id) else { return }
                onOpenCalendar(id)
            } label: {
                HStack(alignment: .top, spacing: SocialFriendCardLayout.contentSpacing) {
                    SocialAvatar(member: friend.member, size: SocialFriendCardLayout.avatarSize)

                    HStack(spacing: 6) {
                        Text(friend.member.name)
                            .font(DPFont.bold(size: 15, relativeTo: .subheadline))
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        if friend.isFamily {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DPColor.warning)
                                .accessibilityLabel(social("social.label.family"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("social.friend.\(friend.member.id ?? -1)")
            .accessibilityHint(
                isPinnedFriendReorderEnabled(friend, isDragPreview: isDragPreview)
                    ? social("social.action.openCalendar") + " " + social("social.hint.pinnedOrder")
                    : social("social.action.openCalendar")
            )
            .accessibilityActions {
                ForEach(accessiblePinnedFriendMoves(friend), id: \.offset) { move in
                    Button(social(move.key)) {
                        guard let memberID = friend.member.id else { return }
                        movePinnedFriend(memberID: memberID, to: move.destinationIndex)
                    }
                }
            }

            HStack(spacing: 0) {
                Button {
                    guard !consumeDragSuppression(for: friend.member.id) else { return }
                    Task { await viewModel.togglePin(friend) }
                } label: {
                    Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(social(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin"))
                .accessibilityIdentifier("social.friend.\(friend.member.id ?? -1).pin")

                Button {
                    guard !consumeDragSuppression(for: friend.member.id) else { return }
                    actionCandidate = ActionCandidate(friend: friend)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DPColor.textMuted)
                        .rotationEffect(.degrees(90))
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(social("social.action.more"))
                .accessibilityIdentifier("social.friend.\(friend.member.id ?? -1).more")
            }
            .frame(width: SocialFriendCardLayout.topActionsWidth, alignment: .topTrailing)
            .popover(
                isPresented: Binding(
                    get: { actionCandidate?.id == friend.member.id },
                    set: { if !$0 { actionCandidate = nil } }
                ),
                arrowEdge: .top
            ) {
                FriendActionPopover(
                    friend: friend,
                    close: { actionCandidate = nil },
                    addFamily: {
                        actionCandidate = nil
                        confirmation = .sendFamily(friend)
                    },
                    removeFamily: {
                        actionCandidate = nil
                        confirmation = .removeFamily(friend)
                    },
                    removeFriend: {
                        actionCandidate = nil
                        confirmation = .removeFriend(friend)
                    },
                    onBlock: {
                        actionCandidate = nil
                        confirmation = .block(friend)
                    }
                )
                .presentationCompactAdaptation(.popover)
            }
            .disabled(isMutationInFlight)
        }
        .padding(DPSpacing.compact)
        .frame(minHeight: 88, alignment: .top)
        .background {
            if friend.pinOrder != nil {
                LinearGradient(
                    colors: [DPColor.backgroundSecondary, DPColor.backgroundTertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                DPColor.backgroundCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(
                    friend.pinOrder == nil ? DPColor.borderPrimary : DPColor.borderSecondary,
                    lineWidth: friend.pinOrder == nil ? 1 : 2
                )
        }
        .shadow(color: Color.black.opacity(friend.pinOrder == nil ? 0.05 : 0.10), radius: 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .dpDragSourceSlot(
            isLifted: draggedPinnedFriendID == friend.member.id && !isDragPreview,
            tint: DPColor.accent,
            cornerRadius: DPRadius.large
        )
        .background {
            if friend.pinOrder != nil && !isDragPreview, let memberID = friend.member.id {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DPPinnedFriendDropTargetPreferenceKey.self,
                        value: [DPPinnedFriendDropTarget(
                            memberID: memberID,
                            frame: proxy.frame(in: .named(SocialFriendDragCoordinateSpace.name))
                        )]
                    )
                }
            }
        }
        .modifier(pinnedFriendReorderGesture(friend, isDragPreview: isDragPreview))
        .dpPressProgress(
            isPressing: pressedPinnedFriendID == friend.member.id,
            isDragging: draggedPinnedFriendID == friend.member.id,
            tint: DPColor.accent
        )
    }

    private func isPinnedFriendReorderEnabled(
        _ friend: DashboardFriendDetailDTO,
        isDragPreview: Bool
    ) -> Bool {
        !isDragPreview && friend.pinOrder != nil && viewModel.pinnedFriends.count >= 2
    }

    /// Social arms the tap suppression inside `updatePinnedFriendDrag`, so both
    /// gesture paths suppress the lift that ends a drag, and the final drag
    /// location the iOS 17 fallback reports is unused: the last `onChanged`
    /// already applied it.
    private func pinnedFriendReorderGesture(
        _ friend: DashboardFriendDetailDTO,
        isDragPreview: Bool
    ) -> DPPinnedFriendReorderGesture {
        DPPinnedFriendReorderGesture(
            isEnabled: isPinnedFriendReorderEnabled(friend, isDragPreview: isDragPreview),
            coordinateSpaceName: SocialFriendDragCoordinateSpace.name,
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
                updatePinnedFriendDrag(memberID: memberID, location: location)
            },
            onChanged: { location in
                guard let memberID = friend.member.id else { return }
                updatePinnedFriendDrag(memberID: memberID, location: location)
            },
            onEnded: { _ in finishPinnedFriendDrag() },
            onCancelled: {
                guard let memberID = friend.member.id else { return }
                cancelPinnedFriendDrag(memberID)
            }
        )
    }

    private func accessiblePinnedFriendMoves(
        _ friend: DashboardFriendDetailDTO
    ) -> [PinnedFriendAccessibleMove] {
        guard friend.pinOrder != nil,
              viewModel.pinnedFriends.count >= 2,
              let memberID = friend.member.id else { return [] }
        let pinnedIDs = displayedPinnedFriends.compactMap(\.member.id)
        guard let index = pinnedIDs.firstIndex(of: memberID) else { return [] }

        var moves: [PinnedFriendAccessibleMove] = []
        if index > 0 {
            moves.append(.init(offset: -1, destinationIndex: index - 1, key: "social.action.moveUp"))
        }
        if index < pinnedIDs.count - 1 {
            moves.append(.init(offset: 1, destinationIndex: index + 1, key: "social.action.moveDown"))
        }
        return moves
    }

    /// The slot the held card currently occupies. Only a drag has a slot, so an
    /// accessibility move — and the inline order being dropped once a save
    /// settles — rewrite `inlinePinnedOrder` without ticking.
    private var pinnedDragRetargetSlot: Int? {
        guard let draggedPinnedFriendID, let inlinePinnedOrder else { return nil }
        return inlinePinnedOrder.firstIndex(of: draggedPinnedFriendID)
    }

    private func cancelPinnedFriendDrag(_ memberID: MemberID) {
        guard draggedPinnedFriendID == memberID else { return }
        clearPinnedFriendDrag()
        scheduleDragSuppressionReset(for: memberID)
    }

    /// A reorder drag keeps the pressed control alive underneath the finger — the
    /// row moves with the drag, so the lift still lands inside the control that
    /// started it. Every control on a pinned card therefore has to swallow the
    /// lift that ends a drag; only the touch that began the drag is suppressed,
    /// so plain taps are untouched.
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

    private func updatePinnedFriendDrag(memberID: MemberID, location: CGPoint) {
        guard !isSavingPinnedOrder, !viewModel.isReordering else { return }
        if draggedPinnedFriendID != memberID {
            let ids = displayedPinnedFriends.compactMap(\.member.id)
            inlinePinnedOrder = ids
            draggedPinnedFriendID = memberID
            dragSuppressedFriendID = memberID
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
        let memberID = draggedPinnedFriendID
        let finalOrder = inlinePinnedOrder
        clearPinnedFriendDrag()
        if let memberID {
            scheduleDragSuppressionReset(for: memberID)
        }
        guard let finalOrder,
              finalOrder != viewModel.pinnedFriends.compactMap(\.member.id) else {
            inlinePinnedOrder = nil
            return
        }
        savePinnedOrder(finalOrder)
    }

    private func movePinnedFriend(memberID: MemberID, to destinationIndex: Int) {
        guard !isSavingPinnedOrder, !viewModel.isReordering else { return }
        var ids = displayedPinnedFriends.compactMap(\.member.id)
        guard let sourceIndex = ids.firstIndex(of: memberID), sourceIndex != destinationIndex else { return }
        ids.remove(at: sourceIndex)
        ids.insert(memberID, at: min(max(0, destinationIndex), ids.count))
        withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
            inlinePinnedOrder = ids
        }
        savePinnedOrder(ids)
    }

    private func savePinnedOrder(_ ids: [MemberID]) {
        guard !isSavingPinnedOrder else { return }
        isSavingPinnedOrder = true
        Task {
            let didSave = await viewModel.savePinnedOrder(ids)
            isSavingPinnedOrder = false
            withAnimation(.snappy(duration: 0.16, extraBounce: 0)) {
                // A failed request restores the model's previous order and the
                // model presents the localized reorder error through its alert.
                inlinePinnedOrder = nil
            }
            if !didSave {
                clearPinnedFriendDrag()
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

#if DEBUG
    private var isSocialReorderUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-social-reorder")
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-social-reorder-overflow")
    }

    private var uiTestingProbes: some View {
        VStack(spacing: 0) {
            uiTestingProbe(
                String(viewModel.uiTestingPinnedOrderSaveCount),
                identifier: "social.reorder.saveCount"
            )
            uiTestingProbe(
                uiTestingPersistedPinnedOrder,
                identifier: "social.reorder.persistedOrder"
            )
            uiTestingProbe(
                String(uiTestingPublishedDropTargetCount),
                identifier: "social.reorder.dropTargetCount"
            )
        }
    }

    private var uiTestingPersistedPinnedOrder: String {
        let ids: [MemberID] = viewModel.pinnedFriends.compactMap { $0.member.id }
        let labels: [String] = ids.map { String($0) }
        return labels.joined(separator: ",")
    }

    /// The number of pinned rows the `LazyVStack` currently publishes a frame for.
    private var uiTestingPublishedDropTargetCount: Int {
        var seen = Set<MemberID>()
        for target in pinnedFriendDropTargets {
            seen.insert(target.memberID)
        }
        return seen.count
    }

    private func uiTestingProbe(_ value: String, identifier: String) -> some View {
        Text(value)
            .font(.system(size: 1))
            .foregroundStyle(Color.clear)
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
    }
#endif

    private var emptyFriends: some View {
        VStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.2")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(DPColor.textMuted)
            Text(social("social.empty.friends"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
            Button(social("social.action.addFriend")) {
                withoutPresentationAnimation { isSearchPresented = true }
            }
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.textOnDark)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DPSpacing.small)
        .disabled(isMutationInFlight)
    }

    private var addFriendCard: some View {
        Button {
            withoutPresentationAnimation { isSearchPresented = true }
        } label: {
            VStack(spacing: DPSpacing.extraSmall) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: 32, height: 32)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(Circle())
                Text(social("social.action.addFriend"))
                    .font(DPFont.bold(size: 12, relativeTo: .caption))
                    .foregroundStyle(DPColor.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(DPColor.borderSecondary, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        }
        .disabled(isMutationInFlight)
    }

    private func perform(
        _ confirmation: SocialConfirmation,
        dismiss: @escaping () -> Void
    ) {
        guard SocialConfirmationActionPolicy.canBegin(
            isPerformingConfirmation: isPerformingConfirmation,
            isPerformingAction: viewModel.isPerformingAction
        ) else { return }
        isPerformingConfirmation = true
        Task {
            await perform(confirmation)
            isPerformingConfirmation = false
            dismiss()
        }
    }

    private func perform(_ confirmation: SocialConfirmation) async {
        switch confirmation {
        case .reject(let request): await viewModel.reject(request)
        case .cancel(let request): await viewModel.cancel(request)
        case .removeFamily(let friend): await viewModel.removeFromFamily(friend)
        case .removeFriend(let friend): await viewModel.removeFriend(friend)
        case .block(let friend): await viewModel.block(friend)
        case .unblock(let member): await viewModel.unblock(member)
        case .sendFamily(let friend): await viewModel.sendFamilyRequest(to: friend)
        }
    }
}

struct SocialPanelHeader: View {
    let title: String
    let count: Int
    let systemImage: String
    let colors: [Color]

    init(
        title: String,
        count: Int,
        systemImage: String,
        colors: [Color]
    ) {
        self.title = title
        self.count = count
        self.systemImage = systemImage
        self.colors = colors
    }

    var body: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(DPFont.bold(size: 16, relativeTo: .body))
            if count > 0 {
                Text(String(count))
                    .font(DPTypography.caption)
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.20))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, count > 0 ? 20 : DPSpacing.large)
        .frame(minHeight: DPSize.minimumTouchTarget)
        .background {
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        }
    }
}

private struct RequestAvatar: View {
    let member: MemberPreviewDTO
    let type: FriendRequestType

    var body: some View {
        SocialAvatar(member: member, size: 36)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: type == .family ? "house.fill" : "person.badge.plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DPColor.textOnDark)
                    .frame(width: 20, height: 20)
                    .background(type == .family ? DPColor.warning : DPColor.accent)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(Color.white, lineWidth: 2) }
                    .offset(x: 3, y: 3)
            }
    }
}

private struct ActionCandidate: Identifiable {
    let friend: DashboardFriendDetailDTO
    var id: MemberID { friend.member.id ?? -1 }
}

struct SocialAvatar: View {
    let member: MemberPreviewDTO
    let size: CGFloat

    var body: some View {
        Group {
            if member.hasProfilePhoto, let id = member.id {
                AsyncImage(url: profileURL(id: id)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(DPColor.backgroundTertiary)
        .clipShape(Circle())
        .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 2) }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(DPColor.textMuted)
            }
    }

    private func profileURL(id: MemberID) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(id)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(member.profilePhotoVersion))
            ])
    }
}

enum SocialFriendCardLayout {
    static let panelInset: CGFloat = 12
    static let avatarSize: CGFloat = 56
    static let contentSpacing: CGFloat = 10
    static let topActionsWidth = DPSize.minimumTouchTarget * 2
}

private struct PinnedFriendAccessibleMove {
    let offset: Int
    let destinationIndex: Int
    let key: String
}

private enum SocialFriendDragCoordinateSpace {
    static let name = "social-friend-drag"
}

nonisolated enum SocialConfirmationActionPolicy {
    static func canBegin(
        isPerformingConfirmation: Bool,
        isPerformingAction: Bool
    ) -> Bool {
        !isPerformingConfirmation && !isPerformingAction
    }
}

private func requestTypeLabel(_ type: FriendRequestType) -> String {
    social(type == .family ? "social.request.family" : "social.request.friend")
}

/// Shared by every file in the Social feature.
func social(_ key: String) -> String {
    AppLocalization.string(key, table: "Social")
}

func socialFormat(_ key: String, _ arguments: CVarArg...) -> String {
    AppLocalization.format(key, table: "Social", arguments: arguments)
}
