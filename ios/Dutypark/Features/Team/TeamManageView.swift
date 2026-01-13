import SwiftUI

struct TeamManageView: View {
    let teamId: Int
    @StateObject private var viewModel: TeamManageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddMemberSheet = false
    @State private var memberToRemove: TeamMemberDto?
    @State private var showRemoveConfirmation = false
    @State private var memberToToggleManager: TeamMemberDto?
    @State private var showManagerToggleConfirmation = false
    @State private var isGrantingManager = true

    init(teamId: Int) {
        self.teamId = teamId
        _viewModel = StateObject(wrappedValue: TeamManageViewModel(teamId: teamId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.team == nil {
                ProgressView()
                    .padding(.top, 100)
            } else if let team = viewModel.team {
                VStack(spacing: 20) {
                    // Team Info Section
                    teamInfoSection(team: team)

                    // Members Section
                    membersSection(team: team)

                    // Duty Types Section
                    dutyTypesSection(team: team)
                }
                .padding()
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("다시 시도") {
                        Task { await viewModel.loadTeam() }
                    }
                }
                .padding(.top, 100)
            }
        }
        .navigationTitle("팀 관리")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadTeam()
        }
        .task {
            await viewModel.loadTeam()
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberSheet(viewModel: viewModel)
        }
        .alert("멤버 제외", isPresented: $showRemoveConfirmation) {
            Button("취소", role: .cancel) { }
            Button("제외", role: .destructive) {
                if let member = memberToRemove {
                    Task { await viewModel.removeMember(member.id) }
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("\(member.name) 님을 팀에서 제외하시겠습니까?")
            }
        }
        .alert(isGrantingManager ? "매니저 권한 부여" : "매니저 권한 취소", isPresented: $showManagerToggleConfirmation) {
            Button("취소", role: .cancel) { }
            Button(isGrantingManager ? "부여" : "취소", role: isGrantingManager ? .none : .destructive) {
                if let member = memberToToggleManager {
                    Task {
                        if isGrantingManager {
                            await viewModel.grantManagerRole(member.id)
                        } else {
                            await viewModel.revokeManagerRole(member.id)
                        }
                    }
                }
            }
        } message: {
            if let member = memberToToggleManager {
                Text(isGrantingManager
                     ? "\(member.name) 님에게 매니저 권한을 부여하시겠습니까?"
                     : "\(member.name) 님의 매니저 권한을 취소하시겠습니까?")
            }
        }
    }

    // MARK: - Team Info Section

    private func teamInfoSection(team: TeamDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("팀 정보")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                infoRow(label: "팀명", value: team.name)
                Divider()
                infoRow(label: "설명", value: team.description ?? "-")
                Divider()
                infoRow(label: "대표", value: team.adminName ?? "없음")
                Divider()
                infoRow(label: "근무 형태", value: workTypeLabel(team.workType))
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
    }

    private func workTypeLabel(_ workType: String) -> String {
        switch workType {
        case "WEEKDAY": return "평일 근무"
        case "WEEKEND": return "주말 근무"
        case "FIXED": return "고정 근무"
        case "FLEXIBLE": return "유연 근무"
        default: return workType
        }
    }

    // MARK: - Members Section

    private func membersSection(team: TeamDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("팀 멤버")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isCurrentUserManager() {
                    Button {
                        showAddMemberSheet = true
                    } label: {
                        Label("추가", systemImage: "person.badge.plus")
                            .font(.subheadline)
                    }
                }
            }

            if team.members.isEmpty {
                Text("멤버가 없습니다")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(team.members.enumerated()), id: \.element.id) { index, member in
                        memberRow(member: member, isManager: viewModel.isCurrentUserManager())

                        if index < team.members.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func memberRow(member: TeamMemberDto, isManager: Bool) -> some View {
        HStack {
            ProfileAvatar(
                memberId: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto ?? false,
                profilePhotoVersion: member.profilePhotoVersion,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.name)
                        .font(.body)

                    if member.isAdmin {
                        Text("대표")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else if member.isManager {
                        Text("매니저")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                if let email = member.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isManager && !member.isAdmin {
                Menu {
                    if member.isManager {
                        Button {
                            memberToToggleManager = member
                            isGrantingManager = false
                            showManagerToggleConfirmation = true
                        } label: {
                            Label("매니저 권한 취소", systemImage: "person.badge.minus")
                        }
                    } else {
                        Button {
                            memberToToggleManager = member
                            isGrantingManager = true
                            showManagerToggleConfirmation = true
                        } label: {
                            Label("매니저 권한 부여", systemImage: "person.badge.plus")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        memberToRemove = member
                        showRemoveConfirmation = true
                    } label: {
                        Label("팀에서 제외", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Duty Types Section

    private func dutyTypesSection(team: TeamDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("근무 유형")
                .font(.headline)
                .foregroundColor(.secondary)

            if team.dutyTypes.isEmpty {
                Text("근무 유형이 없습니다")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(team.dutyTypes.enumerated()), id: \.element.id) { index, dutyType in
                        dutyTypeRow(dutyType: dutyType)

                        if index < team.dutyTypes.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func dutyTypeRow(dutyType: DutyTypeDto) -> some View {
        HStack {
            Circle()
                .fill(dutyType.swiftUIColor)
                .frame(width: 24, height: 24)

            Text(dutyType.name)
                .font(.body)

            if dutyType.id == nil {
                Text("(기본)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    @ObservedObject var viewModel: TeamManageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchKeyword = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("이름 또는 이메일로 검색", text: $searchKeyword)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await viewModel.searchMembers(keyword: searchKeyword) }
                        }

                    if !searchKeyword.isEmpty {
                        Button {
                            searchKeyword = ""
                            viewModel.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                Divider()

                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.3")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(searchKeyword.isEmpty ? "검색어를 입력하세요" : "검색 결과가 없습니다")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.searchResults) { member in
                            memberSearchRow(member: member)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("멤버 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func memberSearchRow(member: MemberDto) -> some View {
        HStack {
            ProfileAvatar(
                memberId: member.id ?? 0,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto ?? false,
                profilePhotoVersion: member.profilePhotoVersion,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)

                if let email = member.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if member.teamId != nil {
                Text("소속 있음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("추가") {
                    guard let memberId = member.id else { return }
                    Task {
                        let success = await viewModel.addMember(memberId)
                        if success {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TeamManageView(teamId: 1)
    }
}
