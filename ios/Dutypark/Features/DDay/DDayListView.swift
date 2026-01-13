import SwiftUI

struct DDayListView: View {
    @StateObject private var viewModel = DDayViewModel()
    @State private var showAddSheet = false
    @State private var selectedDDay: DDayDto?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.ddays.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "D-Day가 없습니다",
                            message: "특별한 날을 추가해보세요",
                            actionTitle: "D-Day 추가"
                        ) {
                            showAddSheet = true
                        }
                        .padding(.top, 60)
                    } else {
                        // Upcoming D-Days (daysLeft >= 0)
                        let upcoming = viewModel.ddays.filter { $0.daysLeft >= 0 }.sorted { $0.daysLeft < $1.daysLeft }
                        if !upcoming.isEmpty {
                            ddaySection(title: "다가오는 D-Day", ddays: upcoming)
                        }

                        // Past D-Days (daysLeft < 0)
                        let past = viewModel.ddays.filter { $0.daysLeft < 0 }.sorted { $0.daysLeft > $1.daysLeft }
                        if !past.isEmpty {
                            ddaySection(title: "지난 D-Day", ddays: past)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("D-Day")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                let memberId = AuthManager.shared.currentUser?.id
                await viewModel.loadDDays(memberId: memberId)
                if let memberId {
                    viewModel.loadPinnedDDay(memberId: memberId)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDDaySheet(viewModel: viewModel)
            }
            .sheet(item: $selectedDDay) { dday in
                DDayDetailSheet(
                    dday: dday,
                    viewModel: viewModel,
                    memberId: AuthManager.shared.currentUser?.id
                ) {
                    selectedDDay = nil
                }
            }
            .task {
                let memberId = AuthManager.shared.currentUser?.id
                await viewModel.loadDDays(memberId: memberId)
                if let memberId {
                    viewModel.loadPinnedDDay(memberId: memberId)
                }
            }
            .loading(viewModel.isLoading)
        }
    }

    private func ddaySection(title: String, ddays: [DDayDto]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            ForEach(ddays) { dday in
                DDayCard(
                    dday: dday,
                    isPinned: viewModel.pinnedDDayId == dday.id,
                    onSelect: {
                        selectedDDay = dday
                    },
                    onTogglePin: {
                        if let memberId = AuthManager.shared.currentUser?.id {
                            viewModel.togglePinnedDDay(dday, memberId: memberId)
                        }
                    },
                    onEdit: nil,
                    onDelete: nil
                )
            }
        }
    }
}

#Preview {
    DDayListView()
}
