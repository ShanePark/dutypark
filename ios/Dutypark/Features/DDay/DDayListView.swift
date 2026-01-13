import SwiftUI

struct DDayListView: View {
    @StateObject private var viewModel = DDayViewModel()
    @State private var showAddSheet = false
    @State private var ddayToDelete: DDayDto?
    @State private var showDeleteConfirmation = false
    @State private var ddayToEdit: DDayDto?

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
                await viewModel.loadDDays()
            }
            .sheet(isPresented: $showAddSheet) {
                AddDDaySheet(viewModel: viewModel)
            }
            .sheet(item: $ddayToEdit) { dday in
                AddDDaySheet(viewModel: viewModel, ddayToEdit: dday)
            }
            .alert("D-Day 삭제", isPresented: $showDeleteConfirmation) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    if let dday = ddayToDelete {
                        Task { await viewModel.deleteDDay(dday.id) }
                    }
                }
            } message: {
                if let dday = ddayToDelete {
                    Text("'\(dday.title)'을(를) 삭제하시겠습니까?")
                }
            }
            .task {
                await viewModel.loadDDays()
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
                    onEdit: {
                        ddayToEdit = dday
                    },
                    onDelete: {
                        ddayToDelete = dday
                        showDeleteConfirmation = true
                    }
                )
            }
        }
    }
}

#Preview {
    DDayListView()
}
