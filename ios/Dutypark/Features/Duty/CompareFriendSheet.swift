import SwiftUI

struct CompareFriendSheet: View {
    @StateObject private var viewModel = FriendsViewModel()
    @Binding var selectedIds: Set<Int>
    let maxSelection: Int
    let onApply: ([Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localSelection: Set<Int> = []
    @State private var showLimitAlert = false

    init(selectedIds: Binding<Set<Int>>, maxSelection: Int = 3, onApply: @escaping ([Int]) -> Void) {
        self._selectedIds = selectedIds
        self.maxSelection = maxSelection
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("선택 \(localSelection.count)/\(maxSelection)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Section("친구 목록") {
                    ForEach(viewModel.friends) { friend in
                        Button {
                            toggleSelection(friend.id)
                        } label: {
                            HStack {
                                ProfileAvatar(
                                    memberId: friend.id,
                                    name: friend.name,
                                    hasProfilePhoto: friend.hasProfilePhoto ?? false,
                                    profilePhotoVersion: friend.profilePhotoVersion,
                                    size: 36
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.name)
                                        .foregroundColor(.primary)
                                    if let team = friend.team {
                                        Text(team)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if localSelection.contains(friend.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("함께보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        selectedIds = localSelection
                        onApply(Array(localSelection))
                        dismiss()
                    }
                }
            }
            .alert("최대 \(maxSelection)명까지 선택할 수 있어요", isPresented: $showLimitAlert) {
                Button("확인", role: .cancel) { }
            }
            .task {
                await viewModel.loadFriends()
                localSelection = selectedIds
            }
        }
    }

    private func toggleSelection(_ id: Int) {
        if localSelection.contains(id) {
            localSelection.remove(id)
            return
        }
        if localSelection.count >= maxSelection {
            showLimitAlert = true
            return
        }
        localSelection.insert(id)
    }
}

#Preview {
    CompareFriendSheet(selectedIds: .constant([])) { _ in }
}
