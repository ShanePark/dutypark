import SwiftUI
import UIKit
import UserNotifications

struct NotificationCenterView: View {
    @ObservedObject var store: NotificationStore
    var onOpen: (NotificationRoute) async -> Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var notificationToDelete: NotificationDTO?
    @State private var showsDeleteReadConfirmation = false
    @State private var alertMessage: String?

    init(
        store: NotificationStore,
        onOpen: @escaping (NotificationRoute) async -> Bool = { _ in true }
    ) {
        self.store = store
        self.onOpen = onOpen
    }

    var body: some View {
        Group {
            if store.isLoading && store.notifications.isEmpty {
                DPLoadingState(label: notificationsKey("notifications.common.loading"))
            } else if store.loadFailed && store.notifications.isEmpty {
                DPErrorState(
                    title: notificationsKey("notifications.messages.loadFailed"),
                    retryTitle: notificationsKey("notifications.common.retry"),
                    retryAction: { Task { await store.refresh() } }
                )
            } else if store.notifications.isEmpty {
                DPEmptyState(
                    systemImage: "bell",
                    title: notificationsKey("notifications.common.empty")
                )
            } else {
                notificationList
            }
        }
        .navigationTitle(String(localized: "notifications.title", table: "Notifications"))
        .toolbar { actions }
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
            String(localized: "notifications.common.error", table: "Notifications"),
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button(String(localized: "notifications.common.ok", table: "Notifications")) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func notificationsKey(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(String(localized: String.LocalizationValue(key), table: "Notifications"))
    }

    private var notificationList: some View {
        List {
            Section {
                ForEach(store.notifications, id: \.id) { notification in
                    Button {
                        Task {
                            if let route = await store.open(notification) {
                                // Keep the notification list visible when a destination
                                // (notably a removed schedule) can no longer be resolved.
                                if await onOpen(route) {
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        NotificationRow(notification: notification)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(notification.isRead ? DPColor.backgroundCard : DPColor.accentSoft)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            notificationToDelete = notification
                        } label: {
                            Label(
                                String(localized: "notifications.common.delete", table: "Notifications"),
                                systemImage: "trash"
                            )
                        }
                    }
                }

                if store.hasMore {
                    Button {
                        Task { await store.loadMore() }
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoadingMore {
                                ProgressView()
                            } else {
                                Text(String(localized: "notifications.list.loadMore", table: "Notifications"))
                            }
                            Spacer()
                        }
                        .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .disabled(store.isLoadingMore)
                }
            } footer: {
                Text(String(localized: "notifications.list.retentionNotice", table: "Notifications"))
            }
        }
        .listStyle(.plain)
        .refreshable { await store.refresh() }
    }

    @ToolbarContentBuilder
    private var actions: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                Task { await markAllAsRead() }
            } label: {
                Label(
                    String(localized: "notifications.list.markAllAsRead", table: "Notifications"),
                    systemImage: "checkmark.circle"
                )
            }
            .disabled(!store.notifications.contains(where: { !$0.isRead }))

            Button {
                showsDeleteReadConfirmation = true
            } label: {
                Label(
                    String(localized: "notifications.list.deleteRead", table: "Notifications"),
                    systemImage: "trash"
                )
            }
            .disabled(!store.notifications.contains(where: \.isRead))
        }
    }

    private func markAllAsRead() async {
        do {
            try await store.markAllAsRead()
        } catch {
            alertMessage = String(localized: "notifications.messages.markAllAsReadFailed", table: "Notifications")
        }
    }

    private func delete(_ notification: NotificationDTO) async {
        do {
            try await store.delete(notification)
        } catch {
            alertMessage = String(localized: "notifications.messages.deleteFailed", table: "Notifications")
        }
        notificationToDelete = nil
    }

    private func deleteAllRead() async {
        do {
            try await store.deleteAllRead()
        } catch {
            alertMessage = String(localized: "notifications.messages.deleteFailed", table: "Notifications")
        }
    }
}

private struct NotificationRow: View {
    let notification: NotificationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                NotificationActorAvatar(notification: notification)
                if !notification.isRead {
                    Circle()
                        .fill(DPColor.accent)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(DPColor.backgroundCard, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(NotificationPresentation.message(for: notification))
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(notification.isRead ? DPColor.textSecondary : DPColor.textPrimary)
                    .multilineTextAlignment(.leading)

                if let date = NotificationPresentation.date(from: notification.createdAt) {
                    HStack(spacing: 4) {
                        Text(date, style: .relative)
                        Text("(\(date.formatted(date: .numeric, time: .shortened)))")
                            .opacity(0.7)
                    }
                    .font(.caption)
                    .foregroundStyle(DPColor.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityIdentifier("notifications.row.\(notification.id.uuidString)")
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

struct NotificationPermissionCard: View {
    @ObservedObject var manager: APNsRegistrationManager

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Label(
                String(localized: "notifications.permission.title", table: "Notifications"),
                systemImage: "bell.badge"
            )
            .font(.headline)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(DPColor.textSecondary)

            if manager.authorizationStatus == .notDetermined {
                Button(String(localized: "notifications.permission.review", table: "Notifications")) {
                    manager.requestPermission()
                }
                .buttonStyle(DPPrimaryButtonStyle())
            } else if manager.authorizationStatus == .denied {
                Button(String(localized: "notifications.permission.openSettings", table: "Notifications")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            } else if manager.registrationState == .failed {
                Button(String(localized: "notifications.common.retry", table: "Notifications")) {
                    Task { await manager.resumeRegistration() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
        .alert(
            String(localized: "notifications.permission.prepromptTitle", table: "Notifications"),
            isPresented: $manager.showsPermissionPreprompt
        ) {
            Button(String(localized: "notifications.permission.continue", table: "Notifications")) {
                Task { await manager.continuePermissionRequest() }
            }
            Button(String(localized: "notifications.common.notNow", table: "Notifications"), role: .cancel) {}
        } message: {
            Text(String(localized: "notifications.permission.prepromptMessage", table: "Notifications"))
        }
    }

    private var statusMessage: String {
        switch manager.authorizationStatus {
        case .notDetermined:
            String(localized: "notifications.permission.notDetermined", table: "Notifications")
        case .denied:
            String(localized: "notifications.permission.denied", table: "Notifications")
        case .authorized, .provisional, .ephemeral:
            switch manager.registrationState {
            case .registered:
                String(localized: "notifications.permission.registered", table: "Notifications")
            case .registering:
                String(localized: "notifications.permission.registering", table: "Notifications")
            case .failed:
                String(localized: "notifications.permission.registrationFailed", table: "Notifications")
            case .idle:
                String(localized: "notifications.permission.granted", table: "Notifications")
            }
        @unknown default:
            String(localized: "notifications.permission.notDetermined", table: "Notifications")
        }
    }
}
