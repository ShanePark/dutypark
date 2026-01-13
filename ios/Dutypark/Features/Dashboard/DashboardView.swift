import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let dashboard = viewModel.dashboard {
                        welcomeSection(dashboard)
                        todayDutySection(dashboard)
                        todaySchedulesSection(dashboard)
                        ddaySection(dashboard)
                    }
                }
                .padding()
            }
            .navigationTitle("홈")
            .refreshable {
                await viewModel.loadDashboard()
            }
            .task {
                await viewModel.loadDashboard()
            }
            .overlay {
                if viewModel.isLoading && viewModel.dashboard == nil {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func welcomeSection(_ dashboard: DashboardResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("안녕하세요, \(dashboard.member.name)님")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let teamName = dashboard.member.teamName {
                    Text(teamName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func todayDutySection(_ dashboard: DashboardResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 근무")
                .font(.headline)

            if let duty = dashboard.todayDuty {
                HStack {
                    Circle()
                        .fill(Color(hex: duty.color) ?? .gray)
                        .frame(width: 12, height: 12)
                    Text(duty.name)
                        .font(.body)
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("등록된 근무가 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func todaySchedulesSection(_ dashboard: DashboardResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 일정")
                .font(.headline)

            if dashboard.todaySchedules.isEmpty {
                Text("오늘 일정이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(dashboard.todaySchedules) { schedule in
                        HStack {
                            if let startTime = schedule.startTime {
                                Text(startTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(schedule.contentWithoutTime ?? schedule.content)
                                .font(.body)
                            Spacer()
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ddaySection(_ dashboard: DashboardResponse) -> some View {
        if !dashboard.pinnedDdays.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("D-Day")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(dashboard.pinnedDdays) { dday in
                        HStack {
                            Text(dday.title)
                                .font(.body)
                            Spacer()
                            Text(dday.displayText)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
}
