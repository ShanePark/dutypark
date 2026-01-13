import SwiftUI

struct AddFriendSheet: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SearchBar(text: $searchText, placeholder: "이름으로 검색") {
                    viewModel.searchQuery = searchText
                    Task { await viewModel.searchFriends() }
                }
                .padding(.horizontal)

                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "person.slash",
                        title: "검색 결과가 없습니다",
                        message: "다른 이름으로 검색해보세요"
                    )
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("친구 이름을 검색해보세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else {
                    List(viewModel.searchResults) { member in
                        HStack {
                            ProfileAvatar(
                                memberId: member.id,
                                name: member.name,
                                hasProfilePhoto: member.hasProfilePhoto ?? false,
                                profilePhotoVersion: member.profilePhotoVersion,
                                size: 40
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.headline)

                                if let team = member.team {
                                    Text(team)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                Task {
                                    let success = await viewModel.sendFriendRequest(to: member.id)
                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("친구 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchQuery = newValue
                Task { await viewModel.searchFriends() }
            }
        }
    }
}

#Preview {
    AddFriendSheet(viewModel: FriendsViewModel())
}
