import SwiftUI
import UniformTypeIdentifiers

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
    @State private var showBatchFileImporter = false
    @State private var selectedBatchFileURL: URL?
    @State private var batchYear: Int = Calendar.current.component(.year, from: Date())
    @State private var batchMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var showBatchResultAlert = false
    @State private var batchResultMessage = ""
    @State private var showDutyTypeSheet = false
    @State private var editingDutyType: DutyTypeDto?
    @State private var showDutyTypeDeleteConfirmation = false
    @State private var dutyTypeToDelete: DutyTypeDto?

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

                    if viewModel.isCurrentUserManager() {
                        // Duty Batch Upload Section
                        batchUploadSection(team: team)
                    }

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
        .fileImporter(
            isPresented: $showBatchFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedBatchFileURL = urls.first
            case .failure(let error):
                batchResultMessage = error.localizedDescription
                showBatchResultAlert = true
            }
        }
        .sheet(isPresented: $showDutyTypeSheet) {
            DutyTypeEditorSheet(
                dutyType: editingDutyType,
                onSave: { name, colorHex in
                    Task {
                        if let dutyType = editingDutyType, let id = dutyType.id {
                            _ = await viewModel.updateDutyType(id: id, name: name, color: colorHex)
                        } else if let dutyType = editingDutyType, dutyType.id == nil {
                            _ = await viewModel.updateDefaultDuty(name: name, color: colorHex)
                        } else {
                            _ = await viewModel.addDutyType(name: name, color: colorHex)
                        }
                    }
                }
            )
        }
        .alert("근무 유형 삭제", isPresented: $showDutyTypeDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                if let dutyType = dutyTypeToDelete, let id = dutyType.id {
                    Task { _ = await viewModel.deleteDutyType(id) }
                }
            }
        } message: {
            if let dutyType = dutyTypeToDelete {
                Text("'\(dutyType.name)' 근무 유형을 삭제하시겠습니까?")
            }
        }
        .alert("업로드 결과", isPresented: $showBatchResultAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(batchResultMessage)
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
                if viewModel.isCurrentUserManager() {
                    menuRow(label: "대표", value: team.adminName ?? "없음") {
                        Button("대표 해제") {
                            Task { await viewModel.changeAdmin(memberId: nil) }
                        }
                        ForEach(team.members.filter { $0.isManager }, id: \.id) { member in
                            Button(member.name) {
                                Task { await viewModel.changeAdmin(memberId: member.id) }
                            }
                        }
                    }
                    Divider()
                    menuRow(label: "근무 형태", value: workTypeLabel(team.workType)) {
                        ForEach(workTypeOptions, id: \.value) { option in
                            Button(option.label) {
                                Task { await viewModel.updateWorkType(option.value) }
                            }
                        }
                    }
                    Divider()
                    menuRow(label: "배치 템플릿", value: team.dutyBatchTemplate?.label ?? "선택 안 함") {
                        Button("선택 안 함") {
                            Task { await viewModel.updateBatchTemplate(templateName: nil) }
                        }
                        ForEach(viewModel.dutyBatchTemplates, id: \.name) { template in
                            Button(template.label) {
                                Task { await viewModel.updateBatchTemplate(templateName: template.name) }
                            }
                        }
                    }
                } else {
                    infoRow(label: "대표", value: team.adminName ?? "없음")
                    Divider()
                    infoRow(label: "근무 형태", value: workTypeLabel(team.workType))
                    Divider()
                    infoRow(label: "배치 템플릿", value: team.dutyBatchTemplate?.label ?? "선택 안 함")
                }
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

    private func menuRow(label: String, value: String, @ViewBuilder menuItems: () -> some View) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Menu {
                menuItems()
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private var workTypeOptions: [(value: String, label: String)] {
        [
            ("WEEKDAY", "평일 근무"),
            ("WEEKEND", "주말 근무"),
            ("FIXED", "고정 근무"),
            ("FLEXIBLE", "유연 근무")
        ]
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

    private func uploadBatch() {
        guard let fileURL = selectedBatchFileURL else { return }
        Task {
            if let result = await viewModel.uploadDutyBatch(fileURL: fileURL, year: batchYear, month: batchMonth) {
                if result.success {
                    batchResultMessage = "업로드가 완료되었습니다."
                    selectedBatchFileURL = nil
                } else {
                    batchResultMessage = result.message.isEmpty ? "업로드에 실패했습니다." : result.message
                }
            } else {
                batchResultMessage = viewModel.error ?? "업로드에 실패했습니다."
            }
            showBatchResultAlert = true
        }
    }

    // MARK: - Batch Upload Section
    private func batchUploadSection(team: TeamDto) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("근무표 업로드")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                HStack {
                    Text(selectedBatchFileURL?.lastPathComponent ?? "파일을 선택해주세요")
                        .font(.subheadline)
                        .foregroundColor(selectedBatchFileURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Button("파일 선택") {
                        showBatchFileImporter = true
                    }
                }

                HStack(spacing: 12) {
                    Picker("연도", selection: $batchYear) {
                        ForEach((Calendar.current.component(.year, from: Date()) - 1)...(Calendar.current.component(.year, from: Date()) + 1), id: \.self) { year in
                            Text("\(year)년").tag(year)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("월", selection: $batchMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)월").tag(month)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if team.dutyBatchTemplate == nil {
                    Text("배치 템플릿을 먼저 선택해주세요.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    uploadBatch()
                } label: {
                    HStack {
                        if viewModel.isUploadingBatch {
                            ProgressView()
                        }
                        Text(viewModel.isUploadingBatch ? "업로드 중..." : "등록")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.isUploadingBatch ? Color.gray.opacity(0.2) : DesignSystem.Colors.accent)
                    .foregroundColor(viewModel.isUploadingBatch ? .secondary : .white)
                    .cornerRadius(12)
                }
                .disabled(selectedBatchFileURL == nil || team.dutyBatchTemplate == nil || viewModel.isUploadingBatch)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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

                        Button {
                            Task { _ = await viewModel.changeAdmin(memberId: member.id) }
                        } label: {
                            Label("대표 위임", systemImage: "crown")
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
            HStack {
                Text("근무 유형")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.isCurrentUserManager() {
                    Button {
                        editingDutyType = nil
                        showDutyTypeSheet = true
                    } label: {
                        Label("추가", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            }

            if team.dutyTypes.isEmpty {
                Text("근무 유형이 없습니다")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(team.dutyTypes.enumerated()), id: \.offset) { index, dutyType in
                        dutyTypeRow(dutyType: dutyType, index: index, totalCount: team.dutyTypes.count, team: team)

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

    private func dutyTypeRow(dutyType: DutyTypeDto, index: Int, totalCount: Int, team: TeamDto) -> some View {
        let isDefault = dutyType.id == nil
        let canMoveUp = !isDefault && index > 1
        let canMoveDown = !isDefault && index < totalCount - 1

        return HStack(spacing: 12) {
            Circle()
                .fill(dutyType.swiftUIColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(dutyType.name)
                    .font(.body)
                if isDefault {
                    Text("휴무")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if viewModel.isCurrentUserManager() {
                HStack(spacing: 8) {
                    if dutyType.id != nil {
                        Button {
                            swapDutyTypePosition(team: team, index: index, targetIndex: index + 1)
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(canMoveDown ? .primary : .secondary)
                        }
                        .disabled(!canMoveDown)

                        Button {
                            swapDutyTypePosition(team: team, index: index, targetIndex: index - 1)
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundColor(canMoveUp ? .primary : .secondary)
                        }
                        .disabled(!canMoveUp)
                    }

                    Button {
                        editingDutyType = dutyType
                        showDutyTypeSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if !isDefault, dutyType.id != nil {
                        Button {
                            dutyTypeToDelete = dutyType
                            showDutyTypeDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
    }

    private func swapDutyTypePosition(team: TeamDto, index: Int, targetIndex: Int) {
        guard targetIndex >= 0, targetIndex < team.dutyTypes.count else { return }
        guard let id1 = team.dutyTypes[index].id, let id2 = team.dutyTypes[targetIndex].id else { return }
        Task { _ = await viewModel.swapDutyTypePosition(id1: id1, id2: id2) }
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
