import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showAddFriendSheet = false
    @State private var selectedFriend: Friend?
    @State private var showFriendActionSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Received Requests Section
                    if !viewModel.receivedRequests.isEmpty {
                        requestsSection(
                            title: "받은 요청",
                            requests: viewModel.receivedRequests,
                            isReceived: true
                        )
                    }

                    // Sent Requests Section
                    if !viewModel.sentRequests.isEmpty {
                        requestsSection(
                            title: "보낸 요청",
                            requests: viewModel.sentRequests,
                            isReceived: false
                        )
                    }

                    // Friends List Section
                    friendsListSection
                }
                .padding()
            }
            .navigationTitle("친구")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriendSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadFriends()
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheet(viewModel: viewModel)
            }
            .confirmationDialog("친구 관리", isPresented: $showFriendActionSheet, presenting: selectedFriend) { friend in
                if friend.isFamily {
                    Button("친구로 변경") {
                        Task { await viewModel.demoteFromFamily(friend.id) }
                    }
                } else {
                    Button("가족으로 변경") {
                        Task { await viewModel.upgradeToFamily(friend.id) }
                    }
                }

                if friend.isPinned {
                    Button("고정 해제") {
                        Task { await viewModel.unpinFriend(friend.id) }
                    }
                } else {
                    Button("상단 고정") {
                        Task { await viewModel.pinFriend(friend.id) }
                    }
                }

                Button("친구 삭제", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
            .alert("친구 삭제", isPresented: $showDeleteConfirmation) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    if let friend = selectedFriend {
                        Task { await viewModel.unfriend(friend.id) }
                    }
                }
            } message: {
                Text("정말 친구를 삭제하시겠습니까?")
            }
            .task {
                await viewModel.loadFriends()
            }
            .loading(viewModel.isLoading)
        }
    }

    private func requestsSection(title: String, requests: [DashboardFriendRequestDto], isReceived: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Text("\(requests.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isReceived ? Color.blue : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            ForEach(requests) { request in
                FriendRequestCard(
                    request: request,
                    isReceived: isReceived,
                    onAccept: {
                        Task { await viewModel.acceptFriendRequest(from: request.fromMember.id ?? 0) }
                    },
                    onReject: {
                        Task { await viewModel.rejectFriendRequest(from: request.fromMember.id ?? 0) }
                    },
                    onCancel: {
                        Task { await viewModel.cancelFriendRequest(to: request.toMember.id ?? 0) }
                    }
                )
            }
        }
    }

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("친구 목록")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.friends.count)명")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if viewModel.friends.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "친구가 없습니다",
                    message: "친구를 추가해보세요",
                    actionTitle: "친구 찾기"
                ) {
                    showAddFriendSheet = true
                }
                .padding(.vertical, 40)
            } else {
                let pinnedFriends = viewModel.friends.filter { $0.isPinned }
                let unpinnedFriends = viewModel.friends.filter { !$0.isPinned }

                ForEach(pinnedFriends + unpinnedFriends) { friend in
                    FriendCard(friend: friend) {
                        selectedFriend = friend
                        showFriendActionSheet = true
                    }
                }
            }
        }
    }
}

#Preview {
    FriendsView()
}
