import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var store: NotificationStore
    var onOpen: (NotificationRoute) async -> Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var notificationToDelete: NotificationDTO?
    @State private var showsDeleteReadConfirmation = false
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
                pageHeader
                    .padding(.bottom, DPSpacing.medium)

                Text(String(localized: "notifications.list.retentionNotice", table: "Notifications"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .padding(.bottom, DPSpacing.medium)

                notificationCard
            }
            .frame(maxWidth: 672)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.large)
            .frame(maxWidth: .infinity)
        }
        .background(DPColor.backgroundPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.visible)
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
        .confirmationDialog(
            String(localized: "notifications.list.deleteConfirmTitle", table: "Notifications"),
            isPresented: Binding(
                get: { notificationToDelete != nil },
                set: { if !$0 { notificationToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "notifications.common.delete", table: "Notifications"), role: .destructive) {
                guard let notificationToDelete else { return }
                Task { await delete(notificationToDelete) }
            }
            Button(String(localized: "notifications.common.cancel", table: "Notifications"), role: .cancel) {}
        } message: {
            Text(String(localized: "notifications.list.deleteConfirmMessage", table: "Notifications"))
        }
        .confirmationDialog(
            String(localized: "notifications.list.deleteAllReadTitle", table: "Notifications"),
            isPresented: $showsDeleteReadConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "notifications.list.deleteRead", table: "Notifications"), role: .destructive) {
                Task { await deleteAllRead() }
            }
            Button(String(localized: "notifications.common.cancel", table: "Notifications"), role: .cancel) {}
        } message: {
            Text(String(localized: "notifications.list.deleteAllReadConfirm", table: "Notifications"))
        }
        .alert(
            alertTitle ?? String(localized: "notifications.common.error", table: "Notifications"),
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
            Button(String(localized: "notifications.common.ok", table: "Notifications")) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var pageHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DPSpacing.compact) {
                pageTitle
                Spacer(minLength: 0)
                headerActions
            }

            VStack(alignment: .leading, spacing: DPSpacing.compact) {
                pageTitle
                headerActions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
    }

    private var pageTitle: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: 36, height: 36)
                .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large)
                        .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                }

            Text(String(localized: "notifications.title", table: "Notifications"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var headerActions: some View {
        HStack(spacing: DPSpacing.small) {
            NotificationHeaderActionButton(
                title: String(localized: "notifications.list.markAllAsReadShort", table: "Notifications"),
                systemImage: "checkmark.circle"
            ) {
                Task { await markAllAsRead() }
            }

            NotificationHeaderActionButton(
                title: String(localized: "notifications.list.deleteReadShort", table: "Notifications"),
                systemImage: "trash",
                isDestructive: true
            ) {
                if store.notifications.contains(where: \.isRead) {
                    showsDeleteReadConfirmation = true
                } else {
                    showInformation("notifications.list.noReadNotifications")
                }
            }
        }
    }

    @ViewBuilder
    private var notificationCard: some View {
        LazyVStack(spacing: 0) {
            if store.isLoading && store.notifications.isEmpty {
                Text(String(localized: "notifications.common.loading", table: "Notifications"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DPSpacing.extraLarge)
            } else if store.loadFailed && store.notifications.isEmpty {
                VStack(spacing: DPSpacing.compact) {
                    Text(String(localized: "notifications.messages.loadFailed", table: "Notifications"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)

                    Button(String(localized: "notifications.common.retry", table: "Notifications")) {
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

                    Text(String(localized: "notifications.common.empty", table: "Notifications"))
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
                        onDelete: { notificationToDelete = notification }
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
                                Text(String(localized: "notifications.list.loadMore", table: "Notifications"))
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

    private func open(_ notification: NotificationDTO) async {
        if let route = await store.open(notification), await onOpen(route) {
            dismiss()
        }
    }

    private func markAllAsRead() async {
        guard store.notifications.contains(where: { !$0.isRead }) else {
            showInformation("notifications.list.noUnreadNotifications")
            return
        }

        do {
            try await store.markAllAsRead()
        } catch {
            alertTitle = String(localized: "notifications.common.error", table: "Notifications")
            alertMessage = String(localized: "notifications.messages.markAllAsReadFailed", table: "Notifications")
        }
    }

    private func delete(_ notification: NotificationDTO) async {
        do {
            try await store.delete(notification)
        } catch {
            alertTitle = String(localized: "notifications.common.error", table: "Notifications")
            alertMessage = String(localized: "notifications.messages.deleteFailed", table: "Notifications")
        }
        notificationToDelete = nil
    }

    private func deleteAllRead() async {
        do {
            try await store.deleteAllRead()
        } catch {
            alertTitle = String(localized: "notifications.common.error", table: "Notifications")
            alertMessage = String(localized: "notifications.messages.deleteFailed", table: "Notifications")
        }
    }

    private func showInformation(_ key: String) {
        alertTitle = String(localized: "notifications.title", table: "Notifications")
        alertMessage = String(localized: String.LocalizationValue(key), table: "Notifications")
    }
}

private struct NotificationRow: View {
    let notification: NotificationDTO
    let onOpen: () -> Void
    let onDelete: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
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

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "notifications.common.delete", table: "Notifications"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
        .background {
            if !notification.isRead {
                ZStack(alignment: .leading) {
                    DPColor.backgroundCard
                    DPColor.accentSoft.opacity(0.45)
                    Rectangle()
                        .fill(DPColor.accent)
                        .frame(width: 4)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityIdentifier("notifications.row.\(notification.id.uuidString)")
    }
}

private struct NotificationHeaderActionButton: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void

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
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationActorAvatar: View {
    let notification: NotificationDTO
    @State private var image: UIImage?

    var body: some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: 40, height: 40)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            .task(id: photoVersion) {
                await loadPhoto()
            }
    }

    private var photoVersion: String {
        "\(notification.actorId ?? 0)-\(notification.payload.actor?.profilePhotoVersion ?? 0)"
    }

    private func loadPhoto() async {
        guard let actorID = notification.actorId,
              notification.payload.actor?.hasProfilePhoto == true
        else {
            image = nil
            return
        }
        let data = try? await APIClient.shared.data(
            "members/\(actorID)/profile-photo",
            queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(
                    name: "v",
                    value: String(notification.payload.actor?.profilePhotoVersion ?? 0)
                ),
            ]
        )
        image = data.flatMap(UIImage.init(data:))
    }
}

struct NotificationBellButton: View {
    @ObservedObject var store: NotificationStore
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
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
                isPresented = true
            } label: {
                Color.clear
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "notifications.title", table: "Notifications"))
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("notifications.bell")
        }
    }

    private var accessibilityValue: String {
        [
            store.unreadCount > 0
                ? String(
                    format: String(localized: "notifications.bell.unread", table: "Notifications"),
                    store.unreadCountLabel
                )
                : nil,
            store.hasFriendRequests
                ? String(
                    format: String(localized: "notifications.bell.friendRequests", table: "Notifications"),
                    store.friendRequestCountLabel
                )
                : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
