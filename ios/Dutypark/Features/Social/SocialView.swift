import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel: SocialViewModel
    @State private var isSearchPresented = false
    @State private var confirmation: SocialConfirmation?
    @State private var actionCandidate: ActionCandidate?
    @State private var dropTargetFriendID: MemberID?

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
        .background(DPColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .fullScreenCover(isPresented: $isSearchPresented) {
            FriendSearchModalView(viewModel: viewModel)
                .presentationBackground(.clear)
        }
        .alert(item: $confirmation) { confirmation in
            confirmationAlert(confirmation)
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
        .disabled(viewModel.isPerformingAction)
    }

    private var friendContent: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.large) {
                pageHeader

                if viewModel.hasPendingRequests {
                    requestsPanel
                }

                friendsPanel
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.small)
            .padding(.bottom, DPSpacing.large)
        }
        .accessibilityIdentifier("social.list")
    }

    private var pageHeader: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: 36, height: 36)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                        .stroke(DPColor.borderPrimary, lineWidth: 1)
                }

            Text(social("social.title"))
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DPSpacing.small)

            Button {
                isSearchPresented = true
            } label: {
                HStack(spacing: DPSpacing.small) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(social("social.action.addFriend"))
                        .font(DPFont.light(size: 14, relativeTo: .subheadline))
                        .lineLimit(1)
                }
                .foregroundStyle(DPColor.textOnDark)
                .padding(.horizontal, DPSpacing.medium)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background {
                    LinearGradient(
                        colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("social.addFriend")
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
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
                    ForEach(viewModel.pinnedFriends, id: \.member.id) { friend in
                        friendCard(friend)
                    }
                    ForEach(viewModel.unpinnedFriends, id: \.member.id) { friend in
                        friendCard(friend)
                    }
                }

                addFriendCard
            }
            .padding(20)
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
        HStack(spacing: DPSpacing.compact) {
            RequestAvatar(member: request.fromMember, type: request.requestType)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromMember.name)
                    .font(DPFont.light(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(requestTypeLabel(request.requestType))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DPSpacing.extraSmall)

            HStack(spacing: DPSpacing.small) {
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
        HStack(spacing: DPSpacing.compact) {
            RequestAvatar(member: request.toMember, type: request.requestType)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.toMember.name)
                    .font(DPFont.light(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(socialFormat("social.request.sent", requestTypeLabel(request.requestType)))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DPSpacing.extraSmall)

            compactActionButton(
                social("social.action.cancel"),
                foreground: DPColor.warningHover,
                background: DPColor.backgroundCard,
                border: DPColor.warningBorder
            ) {
                confirmation = .cancel(request)
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

    @ViewBuilder
    private func friendCard(_ friend: DashboardFriendDetailDTO) -> some View {
        if friend.pinOrder != nil, let friendID = friend.member.id {
            friendCardBody(friend)
                .draggable(String(friendID)) {
                    PinnedFriendDragPreview(friend: friend)
                }
                .dropDestination(
                    for: String.self,
                    action: { items, _ in
                        dropTargetFriendID = nil
                        guard let sourceValue = items.first,
                              let sourceID = MemberID(sourceValue),
                              sourceID != friendID else { return false }
                        Task {
                            await viewModel.reorderPinned(
                                draggedID: sourceID,
                                over: friendID
                            )
                        }
                        return true
                    },
                    isTargeted: { isTargeted in
                        withAnimation(.easeOut(duration: 0.16)) {
                            dropTargetFriendID = isTargeted ? friendID : nil
                        }
                    }
                )
                .overlay {
                    if dropTargetFriendID == friendID {
                        RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                            .stroke(DPColor.accent, lineWidth: 3)
                            .padding(2)
                            .allowsHitTesting(false)
                    }
                }
                .scaleEffect(dropTargetFriendID == friendID ? 1.015 : 1)
                .animation(.easeOut(duration: 0.16), value: dropTargetFriendID)
        } else {
            friendCardBody(friend)
        }
    }

    private func friendCardBody(_ friend: DashboardFriendDetailDTO) -> some View {
        HStack(spacing: DPSpacing.compact) {
            Button {
                if let id = friend.member.id { onOpenCalendar(id) }
            } label: {
                HStack(alignment: .top, spacing: DPSpacing.compact) {
                    SocialAvatar(member: friend.member, size: 64)

                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        HStack(spacing: 6) {
                            Text(friend.member.name)
                                .font(DPFont.light(size: 14, relativeTo: .subheadline))
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            if friend.isFamily {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DPColor.warning)
                                    .accessibilityLabel(social("social.label.family"))
                            }
                        }

                        if let team = friend.member.team, !team.isEmpty {
                            Label(team, systemImage: "person.3")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textSecondary)
                                .lineLimit(1)
                        }

                        if let duty = friend.duty {
                            Label(
                                duty.dutyType ?? social("social.label.offDuty"),
                                systemImage: "briefcase"
                            )
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(1)
                        }

                        ForEach(Array(friend.schedules.prefix(2)), id: \.id) { schedule in
                            Label(scheduleLabel(schedule), systemImage: "calendar")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textSecondary)
                                .lineLimit(1)
                        }

                        if friend.schedules.count > 2 {
                            Text(
                                socialFormat(
                                    "social.label.moreSchedules",
                                    String(friend.schedules.count - 2)
                                )
                            )
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint(social("social.action.openCalendar"))
            .accessibilityActions {
                if friend.pinOrder != nil {
                    Button(social("social.action.moveUp")) {
                        movePinned(friend, direction: -1)
                    }
                    Button(social("social.action.moveDown")) {
                        movePinned(friend, direction: 1)
                    }
                }
            }

            Spacer(minLength: DPSpacing.small)

            HStack(spacing: 0) {
                Button {
                    Task { await viewModel.togglePin(friend) }
                } label: {
                    Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(social(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin"))

                Button {
                    actionCandidate = ActionCandidate(friend: friend)
                } label: {
                    Image(systemName: "ellipsis.vertical")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DPColor.textMuted)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(social("social.action.more"))
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
                            Task { await viewModel.sendFamilyRequest(to: friend) }
                        },
                        removeFamily: {
                            actionCandidate = nil
                            confirmation = .removeFamily(friend)
                        },
                        removeFriend: {
                            actionCandidate = nil
                            confirmation = .removeFriend(friend)
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
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
    }

    private func movePinned(_ friend: DashboardFriendDetailDTO, direction: Int) {
        guard friend.pinOrder != nil,
              let sourceIndex = viewModel.pinnedFriends.firstIndex(where: {
                  $0.member.id == friend.member.id
              }) else { return }

        let destinationIndex = sourceIndex + direction
        guard viewModel.pinnedFriends.indices.contains(destinationIndex) else { return }

        Task {
            await viewModel.movePinned(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: direction < 0 ? destinationIndex : destinationIndex + 1
            )
        }
    }

    private var emptyFriends: some View {
        VStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.2")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(DPColor.textMuted)
            Text(social("social.empty.friends"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
            Button(social("social.action.addFriend")) {
                isSearchPresented = true
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
    }

    private var addFriendCard: some View {
        Button {
            isSearchPresented = true
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
    }

    private func confirmationAlert(_ confirmation: SocialConfirmation) -> Alert {
        Alert(
            title: Text(social(confirmation.titleKey)),
            message: Text(socialFormat(confirmation.messageKey, confirmation.memberName)),
            primaryButton: .destructive(Text(social(confirmation.confirmKey))) {
                Task { await perform(confirmation) }
            },
            secondaryButton: .cancel(Text(social("social.action.cancelDialog")))
        )
    }

    private func perform(_ confirmation: SocialConfirmation) async {
        switch confirmation {
        case .reject(let request): await viewModel.reject(request)
        case .cancel(let request): await viewModel.cancel(request)
        case .removeFamily(let friend): await viewModel.removeFromFamily(friend)
        case .removeFriend(let friend): await viewModel.removeFriend(friend)
        }
    }
}

private struct PinnedFriendDragPreview: View {
    let friend: DashboardFriendDetailDTO

    var body: some View {
        HStack(spacing: DPSpacing.compact) {
            SocialAvatar(member: friend.member, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.member.name)
                    .font(DPFont.bold(size: 15, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(social("social.section.pinned"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DPColor.accent)
        }
        .padding(.horizontal, DPSpacing.medium)
        .frame(minHeight: 60)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(DPColor.borderSecondary, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
    }
}

private struct SocialPanelHeader: View {
    let title: String
    let count: Int
    let systemImage: String
    let colors: [Color]

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
        .frame(height: 44)
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

private struct FriendActionPopover: View {
    let friend: DashboardFriendDetailDTO
    let close: () -> Void
    let addFamily: () -> Void
    let removeFamily: () -> Void
    let removeFriend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Text(friend.member.name)
                    .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DPColor.textMuted)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, 6)
            .background(DPColor.backgroundTertiary)

            Divider().overlay(DPColor.borderPrimary)

            if friend.isFamily {
                actionButton(
                    social("social.action.removeFamily"),
                    image: "person.badge.minus",
                    color: DPColor.warning,
                    action: removeFamily
                )
            } else {
                actionButton(
                    social("social.action.addFamily"),
                    image: "house",
                    color: DPColor.accent,
                    action: addFamily
                )
            }

            actionButton(
                social("social.action.removeFriend"),
                image: "trash",
                color: DPColor.danger,
                action: removeFriend
            )
        }
        .frame(width: 176)
        .background(DPColor.backgroundCard)
    }

    private func actionButton(
        _ title: String,
        image: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: image).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer()
            }
            .font(DPFont.light(size: 14, relativeTo: .subheadline))
            .foregroundStyle(color)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FriendSearchModalView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var candidate: SearchCandidate?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.50)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 0) {
                    modalHeader
                    modalBody
                    modalFooter
                }
                .frame(maxWidth: proxy.size.width - 32)
                .frame(maxHeight: proxy.size.height * 0.85)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous))
                .shadow(color: Color.black.opacity(0.24), radius: 18, y: 8)
                .padding(.vertical, DPSpacing.medium)
            }
        }
        .onDisappear { viewModel.clearSearch() }
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

    private var modalHeader: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DPColor.textOnDark)
                .frame(width: 40, height: 40)
                .background {
                    LinearGradient(
                        colors: [DPColor.accent, DPColor.accentHover],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))

            Text(social("social.search.title"))
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(social("social.action.close"))
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.compact)
        .background(DPColor.backgroundTertiary)
        .overlay(alignment: .bottom) { Divider().overlay(DPColor.borderPrimary) }
    }

    private var modalBody: some View {
        ScrollView {
            VStack(spacing: DPSpacing.medium) {
                searchBar

                if viewModel.isSearching {
                    ProgressView(social("social.search.loading"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 112)
                } else if viewModel.searchResults.isEmpty {
                    VStack(spacing: DPSpacing.compact) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(DPColor.borderSecondary)
                        Text(social("social.search.empty"))
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 152)
                } else {
                    searchResults
                }
            }
            .padding(DPSpacing.medium)
        }
    }

    private var searchBar: some View {
        HStack(spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DPColor.textMuted)
                TextField(social("social.search.prompt"), text: $keyword)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { search(page: 0) }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(DPColor.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                    .stroke(DPColor.borderInput, lineWidth: 1)
            }

            Button { search(page: 0) } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textOnDark)
                    .frame(width: 48, height: 48)
                    .background {
                        LinearGradient(
                            colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
            .opacity(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private var searchResults: some View {
        VStack(spacing: DPSpacing.medium) {
            VStack(spacing: DPSpacing.small) {
                ForEach(viewModel.searchResults, id: \.id) { member in
                    HStack(spacing: DPSpacing.compact) {
                        SocialAvatar(member: member, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(DPFont.bold(size: 16, relativeTo: .body))
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            if let team = member.team, !team.isEmpty {
                                Text(team)
                                    .font(DPTypography.supporting)
                                    .foregroundStyle(DPColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: DPSpacing.small)
                        Button(social("social.action.sendRequest")) {
                            candidate = SearchCandidate(member: member)
                        }
                        .font(DPFont.light(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(DPColor.textOnDark)
                        .padding(.horizontal, DPSpacing.compact)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.success)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                    }
                    .padding(DPSpacing.medium)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                }
            }

            if viewModel.searchTotalPages > 1 {
                HStack(spacing: DPSpacing.small) {
                    pageButton(systemImage: "chevron.left", disabled: viewModel.searchPage == 0) {
                        search(page: viewModel.searchPage - 1)
                    }
                    Text(
                        socialFormat(
                            "social.search.page",
                            String(viewModel.searchPage + 1),
                            String(viewModel.searchTotalPages)
                        )
                    )
                    .font(DPFont.light(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    pageButton(
                        systemImage: "chevron.right",
                        disabled: viewModel.searchPage + 1 >= viewModel.searchTotalPages
                    ) {
                        search(page: viewModel.searchPage + 1)
                    }
                }
            }

            Text(
                socialFormat(
                    "social.search.resultsSummary",
                    String(viewModel.searchPage + 1),
                    String(max(viewModel.searchTotalPages, 1)),
                    String(viewModel.searchTotalElements)
                )
            )
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.textSecondary)
        }
    }

    private func pageButton(
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DPColor.textPrimary)
                .frame(width: 40, height: 40)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                        .stroke(DPColor.borderPrimary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var modalFooter: some View {
        HStack {
            Spacer()
            Button(social("social.action.close")) { dismiss() }
                .font(DPFont.light(size: 14, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textPrimary)
                .padding(.horizontal, 20)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        }
        .padding(DPSpacing.medium)
        .overlay(alignment: .top) { Divider().overlay(DPColor.borderPrimary) }
    }

    private func search(page: Int) {
        Task { await viewModel.search(keyword: keyword, page: page) }
    }
}

private struct SearchCandidate: Identifiable {
    let member: MemberPreviewDTO
    var id: MemberID { member.id ?? -1 }
}

private struct ActionCandidate: Identifiable {
    let friend: DashboardFriendDetailDTO
    var id: MemberID { friend.member.id ?? -1 }
}

private struct SocialAvatar: View {
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

private enum SocialConfirmation: Identifiable {
    case reject(FriendRequestDTO)
    case cancel(FriendRequestDTO)
    case removeFamily(DashboardFriendDetailDTO)
    case removeFriend(DashboardFriendDetailDTO)

    var id: String {
        switch self {
        case .reject(let request): "reject-\(request.id)"
        case .cancel(let request): "cancel-\(request.id)"
        case .removeFamily(let friend): "family-\(friend.member.id ?? -1)"
        case .removeFriend(let friend): "friend-\(friend.member.id ?? -1)"
        }
    }

    var memberName: String {
        switch self {
        case .reject(let request): request.fromMember.name
        case .cancel(let request): request.toMember.name
        case .removeFamily(let friend), .removeFriend(let friend): friend.member.name
        }
    }

    var titleKey: String {
        switch self {
        case .reject: "social.confirm.reject.title"
        case .cancel: "social.confirm.cancel.title"
        case .removeFamily: "social.confirm.removeFamily.title"
        case .removeFriend: "social.confirm.removeFriend.title"
        }
    }

    var messageKey: String {
        switch self {
        case .reject: "social.confirm.reject.message"
        case .cancel: "social.confirm.cancel.message"
        case .removeFamily: "social.confirm.removeFamily.message"
        case .removeFriend: "social.confirm.removeFriend.message"
        }
    }

    var confirmKey: String {
        switch self {
        case .reject: "social.action.reject"
        case .cancel: "social.action.cancel"
        case .removeFamily: "social.action.removeFamily"
        case .removeFriend: "social.action.removeFriend"
        }
    }
}

private func requestTypeLabel(_ type: FriendRequestType) -> String {
    social(type == .family ? "social.request.family" : "social.request.friend")
}

private func scheduleLabel(_ schedule: ScheduleDTO) -> String {
    guard schedule.totalDays > 1 else { return schedule.content }
    return "\(schedule.content) [\(schedule.daysFromStart)/\(schedule.totalDays)]"
}

private func social(_ key: String) -> String {
    AppLocalization.string(key, table: "Social")
}

private func socialFormat(_ key: String, _ arguments: CVarArg...) -> String {
    AppLocalization.format(key, table: "Social", arguments: arguments)
}
