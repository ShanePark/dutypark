import SwiftUI

struct NotificationListView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @State private var showMarkAllConfirmation = false
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "알림이 없습니다",
                        message: "새로운 알림이 오면 여기에 표시됩니다"
                    )
                } else {
                    notificationList
                }
            }
            .navigationTitle("알림")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showMarkAllConfirmation = true
                        } label: {
                            Label("모두 읽음 처리", systemImage: "checkmark.circle")
                        }
                        .disabled(viewModel.unreadCount == 0)

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("읽은 알림 삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadNotifications(refresh: true)
            }
            .alert("모두 읽음 처리", isPresented: $showMarkAllConfirmation) {
                Button("취소", role: .cancel) { }
                Button("확인") {
                    Task { await viewModel.markAllAsRead() }
                }
            } message: {
                Text("모든 알림을 읽음 처리하시겠습니까?")
            }
            .alert("읽은 알림 삭제", isPresented: $showDeleteAllConfirmation) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    Task { await viewModel.deleteAllRead() }
                }
            } message: {
                Text("읽은 알림을 모두 삭제하시겠습니까?")
            }
            .task {
                await viewModel.loadNotifications(refresh: true)
            }
        }
    }

    private var notificationList: some View {
        List {
            ForEach(viewModel.notifications) { notification in
                NotificationRow(notification: notification) {
                    Task {
                        if !notification.isRead {
                            await viewModel.markAsRead(notification.id)
                        }
                        // Handle navigation based on reference type
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteNotification(notification.id) }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }

                    if !notification.isRead {
                        Button {
                            Task { await viewModel.markAsRead(notification.id) }
                        } label: {
                            Label("읽음", systemImage: "checkmark")
                        }
                        .tint(.blue)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
                .padding(.horizontal)
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        Task { await viewModel.loadNotifications() }
                    }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    NotificationListView()
}
