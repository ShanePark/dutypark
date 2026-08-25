import SwiftUI

nonisolated func notificationLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Notifications", locale: locale)
}

nonisolated enum NotificationDeletionConfirmation: Equatable, Identifiable, Sendable {
    enum ID: Equatable, Hashable, Sendable {
        case notification(NotificationID)
        case allRead
    }

    case notification(NotificationDTO)
    case allRead

    var id: ID {
        switch self {
        case let .notification(notification): .notification(notification.id)
        case .allRead: .allRead
        }
    }

    var titleKey: String {
        switch self {
        case .notification: "notifications.list.deleteConfirmTitle"
        case .allRead: "notifications.list.deleteAllReadTitle"
        }
    }

    var messageKey: String {
        switch self {
        case .notification: "notifications.list.deleteConfirmMessage"
        case .allRead: "notifications.list.deleteAllReadConfirm"
        }
    }

    var confirmTitleKey: String {
        switch self {
        case .notification: "notifications.common.delete"
        case .allRead: "notifications.list.deleteRead"
        }
    }
}

struct NotificationCenterView: View {
    @ObservedObject var store: NotificationStore
    var onOpen: (NotificationRoute) async -> Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var deletionConfirmation: NotificationDeletionConfirmation?
    @State private var alertTitle: String?
    @State private var alertMessage: String?

    init(
        store: NotificationStore,
        onOpen: @escaping (NotificationRoute) async -> Bool = { _ in true }
    ) {
        self.store = store
        self.onOpen = onOpen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                bulkActionBar
                    .padding(.bottom, DPSpacing.medium)

                notificationCard
            }
            .frame(maxWidth: 672)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .background(DPColor.backgroundSecondary)
        .accessibilityIdentifier("screen.notifications")
        // Pushed like every other menu screen, so it leaves through the navigation bar
        // instead of a sheet-only swipe down.
        .navigationTitle(notificationLocalized("notifications.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .task {
            store.startPolling()
            if store.notifications.isEmpty {
                await store.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            Task { await store.setForeground(phase == .active) }
        }
        .dpConfirmation(
            item: $deletionConfirmation,
            copy: { confirmation in
                DPConfirmationCopy(
                    title: notificationLocalized(confirmation.titleKey),
                    message: notificationLocalized(confirmation.messageKey),
                    confirmTitle: notificationLocalized(confirmation.confirmTitleKey),
                    cancelTitle: notificationLocalized("notifications.common.cancel"),
                    isDestructive: true
                )
            },
            confirm: { confirmation, dismiss in
                dismiss()
                Task { await delete(confirmation) }
            }
        )
        .alert(
            alertTitle ?? notificationLocalized("notifications.common.error"),
            isPresented: Binding(
                get: { alertMessage != nil },
                set: {
                    if !$0 {
                        alertTitle = nil
                        alertMessage = nil
                    }
                }
            )
        ) {
            Button(notificationLocalized("notifications.common.ok")) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // The retention notice never filled its row and the bulk actions read as two
    // unlabelled glyphs in the navigation bar, so they share the row instead: named
    // buttons at its trailing end, where there is width to spare.
    private var bulkActionBar: some View {
        HStack(alignment: .center, spacing: DPSpacing.compact) {
            Text(notificationLocalized("notifications.list.retentionNotice"))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DPSpacing.small) {
                NotificationHeaderActionButton(
                    title: notificationLocalized("notifications.list.markAllAsReadShort"),
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: "notifications.markAllAsRead"
                ) {
                    Task { await markAllAsRead() }
                }

                NotificationHeaderActionButton(
                    title: notificationLocalized("notifications.list.deleteReadShort"),
                    systemImage: "trash",
                    isDestructive: true,
                    accessibilityIdentifier: "notifications.deleteRead"
                ) {
                    if store.notifications.contains(where: \.isRead) {
                        requestDelete(.allRead)
                    } else {
                        showInformation("notifications.list.noReadNotifications")
                    }
                }
            }
            .layoutPriority(1)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
    }

    @ViewBuilder
    private var notificationCard: some View {
        LazyVStack(spacing: 0) {
            if store.isLoading && store.notifications.isEmpty {
                Text(notificationLocalized("notifications.common.loading"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DPSpacing.extraLarge)
            } else if store.loadFailed && store.notifications.isEmpty {
                VStack(spacing: DPSpacing.compact) {
                    Text(notificationLocalized("notifications.messages.loadFailed"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)

                    Button(notificationLocalized("notifications.common.retry")) {
                        Task { await store.refresh() }
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.extraLarge)
            } else if store.notifications.isEmpty {
                VStack(spacing: DPSpacing.medium) {
                    Image(systemName: "bell")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(DPColor.textMuted.opacity(0.5))

                    Text(notificationLocalized("notifications.common.empty"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                ForEach(Array(store.notifications.enumerated()), id: \.element.id) { index, notification in
                    NotificationRow(
                        notification: notification,
                        onOpen: { Task { await open(notification) } },
                        onDelete: { requestDelete(.notification(notification)) }
                    )

                    if index < store.notifications.count - 1 || store.hasMore {
                        Divider()
                            .overlay(DPColor.borderPrimary)
                    }
                }

                if store.hasMore {
                    Button {
                        Task { await store.loadMore() }
                    } label: {
                        Group {
                            if store.isLoadingMore {
                                ProgressView()
                                    .tint(DPColor.textSecondary)
                            } else {
                                Text(notificationLocalized("notifications.list.loadMore"))
                                    .font(DPTypography.label)
                                    .foregroundStyle(DPColor.textSecondary)
                            }
                        }
                        .padding(.horizontal, DPSpacing.large)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoadingMore)
                    .frame(maxWidth: .infinity)
                    .padding(DPSpacing.medium)
                }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // Every route either switches tabs or replaces the stack this screen sits on, so
    // opening a notification needs no dismissal of its own.
    private func open(_ notification: NotificationDTO) async {
        guard let route = await store.open(notification) else { return }
        _ = await onOpen(route)
    }

    private func markAllAsRead() async {
        guard store.notifications.contains(where: { !$0.isRead }) else {
            showInformation("notifications.list.noUnreadNotifications")
            return
        }

        do {
            try await store.markAllAsRead()
        } catch {
            alertTitle = notificationLocalized("notifications.common.error")
            alertMessage = notificationLocalized("notifications.messages.markAllAsReadFailed")
        }
    }

    private func delete(_ confirmation: NotificationDeletionConfirmation) async {
        do {
            switch confirmation {
            case let .notification(notification):
                try await store.delete(notification)
            case .allRead:
                try await store.deleteAllRead()
            }
        } catch {
            alertTitle = notificationLocalized("notifications.common.error")
            alertMessage = notificationLocalized("notifications.messages.deleteFailed")
        }
    }

    private func showInformation(_ key: String) {
        alertTitle = notificationLocalized("notifications.title")
        alertMessage = notificationLocalized(key)
    }

    private func requestDelete(_ confirmation: NotificationDeletionConfirmation) {
        deletionConfirmation = confirmation
    }
}

private struct NotificationRow: View {
    let notification: NotificationDTO
    let onOpen: () -> Void
    let onDelete: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        NotificationRowSwipe(
            deleteLabel: notificationLocalized("notifications.common.delete"),
            deleteIdentifier: "notifications.row.\(notification.id.uuidString).delete",
            onDelete: onDelete
        ) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: DPSpacing.compact) {
                    ZStack(alignment: .topTrailing) {
                        NotificationActorAvatar(notification: notification)
                        if !notification.isRead {
                            Circle()
                                .fill(DPColor.accent)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(DPColor.backgroundCard, lineWidth: 2))
                                .offset(x: 2, y: -2)
                        }
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NotificationPresentation.message(for: notification))
                            .font(notification.isRead ? DPTypography.label : DPFont.bold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(notification.isRead ? DPColor.textSecondary : DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if let date = NotificationPresentation.date(from: notification.createdAt) {
                            HStack(spacing: DPSpacing.small) {
                                Text(date, style: .relative)
                                Text("(\(NotificationPresentation.absoluteDate(date, locale: locale)))")
                                    .opacity(0.7)
                            }
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("notifications.row.\(notification.id.uuidString).open")
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.compact)
            .background {
                ZStack(alignment: .leading) {
                    DPColor.backgroundCard
                    if !notification.isRead {
                        DPColor.accentSoft.opacity(0.45)
                        Rectangle()
                            .fill(DPColor.accent)
                            .frame(width: 4)
                    }
                }
            }
            .contentShape(Rectangle())
        }
    }
}

/// Reveals a delete button when the row is swiped left.
///
/// The rows sit in a lazy stack rather than a `List`, so `swipeActions` is not
/// available and a `DragGesture` of the row's own would compete with the vertical
/// scroll view it lives in. A nested horizontal scroll view carries the swipe
/// instead: perpendicular axes coexist, so scrolling the list from a row still works.
private struct NotificationRowSwipe<Content: View>: View {
    let deleteLabel: String
    let deleteIdentifier: String
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var isDeleteActionRevealed = false

    private static var actionWidth: CGFloat { 84 }
    private var coordinateSpaceName: String { "notification-row-swipe-(deleteIdentifier)" }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                content
                    .containerRelativeFrame(.horizontal)

                Button(action: onDelete) {
                    VStack(spacing: DPSpacing.extraSmall) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .regular))
                        Text(deleteLabel)
                            .font(DPFont.light(size: 12, relativeTo: .caption))
                            .lineLimit(1)
                    }
                    .foregroundStyle(DPColor.textOnDark)
                    .frame(width: Self.actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(DPColor.danger)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(deleteIdentifier)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: NotificationRowSwipeOffsetKey.self,
                            value: proxy.frame(in: .named(coordinateSpaceName)).minX
                        )
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(NotificationRowSwipeSnap(actionWidth: Self.actionWidth))
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(NotificationRowSwipeOffsetKey.self) { offset in
            let revealed = offset <= -Self.actionWidth / 2
            guard revealed != isDeleteActionRevealed else { return }
            isDeleteActionRevealed = revealed
            guard revealed else { return }
            DPHapticCenter.shared.emit(.selection)
        }
    }
}

private struct NotificationRowSwipeOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Settles a swiped row either closed or fully open, never part-way.
private struct NotificationRowSwipeSnap: ScrollTargetBehavior {
    let actionWidth: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = target.rect.minX > actionWidth / 2 ? actionWidth : 0
    }
}

struct NotificationHeaderActionButton: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                Text(title)
                    .font(DPFont.light(size: 12, relativeTo: .caption))
                    .lineLimit(1)
            }
            .foregroundStyle(isDestructive ? DPColor.textMuted : DPColor.textSecondary)
            .padding(.horizontal, 10)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct NotificationActorAvatar: View {
    let notification: NotificationDTO

    var body: some View {
        DPProfileAvatar(
            memberID: notification.actorId,
            hasProfilePhoto: notification.payload.actor?.hasProfilePhoto,
            profilePhotoVersion: notification.payload.actor?.profilePhotoVersion ?? 0,
            size: 40
        )
    }
}

struct NotificationBellButton: View {
    @ObservedObject var store: NotificationStore
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            present()
        } label: {
            Image(systemName: store.unreadCount > 0 ? "bell.badge.fill" : "bell")
                .symbolRenderingMode(.hierarchical)
                .overlay(alignment: .topTrailing) {
                    if store.unreadCount > 0 {
                        Text(store.unreadCountLabel)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(DPColor.danger, in: Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if store.hasFriendRequests {
                        HStack(spacing: 1) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 7, weight: .bold))
                            Text(store.friendRequestCountLabel)
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(DPColor.textOnDark)
                        .padding(.horizontal, 3)
                        .frame(minHeight: 14)
                        .background(DPColor.warning, in: Capsule())
                        .offset(x: -6, y: 8)
                        .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityRepresentation {
            Button {
                present()
            } label: {
                Color.clear
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(notificationLocalized("notifications.title"))
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("notifications.bell")
        }
    }

    private func present() {
        guard !isPresented else { return }
        isPresented = true
    }

    private var accessibilityValue: String {
        [
            store.unreadCount > 0
                ? AppLocalization.format(
                    "notifications.bell.unread",
                    table: "Notifications",
                    arguments: [store.unreadCountLabel]
                )
                : nil,
            store.hasFriendRequests
                ? AppLocalization.format(
                    "notifications.bell.friendRequests",
                    table: "Notifications",
                    arguments: [store.friendRequestCountLabel]
                )
                : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
