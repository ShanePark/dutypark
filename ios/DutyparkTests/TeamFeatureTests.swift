import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
struct TeamFeatureTests {
    @Test(arguments: [false, true])
    func scheduleDeleteConfirmationOnlyAllowsInteractionWhileIdle(isDeleting: Bool) {
        #expect(
            TeamScheduleDeleteConfirmationPolicy.canSubmit(isDeleting: isDeleting)
                == !isDeleting
        )
        #expect(
            TeamScheduleDeleteConfirmationPolicy.canDismiss(isDeleting: isDeleting)
                == !isDeleting
        )
    }

    @Test @MainActor
    func scheduleDeleteConfirmationNamesTheScheduleAndExplainsTheIrreversibleImpact() {
        let korean = TeamLocalization.scheduleDeletionMessage(title: "회의", locale: .korean)
        #expect(korean.contains("“회의”"))
        #expect(korean.contains("삭제된 일정은 복구할 수 없습니다"))

        let english = TeamLocalization.scheduleDeletionMessage(title: "Meeting", locale: .english)
        #expect(english.contains("“Meeting”"))
        #expect(english.contains("Deleted schedules cannot be restored"))
    }

    @Test @MainActor
    func shiftMemberCountIncludesTheLocalizedUnit() {
        #expect(TeamLocalization.shiftMemberCount(3, locale: .korean) == "3명")
        #expect(TeamLocalization.shiftMemberCount(3, locale: .english) == "3 people")
    }

    @Test
    func scheduleDeletionUsesCenteredPanelAndKeepsTheGeneralErrorAlert() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("DPConfirmationPanel("))
        #expect(source.contains(".fullScreenCover("))
        #expect(source.contains("Text(\"team.common.error\", tableName: \"Team\")"))
    }

    @Test
    func scheduleEditorDismissalHasASinglePresentationOwner() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let editor = try #require(source.range(of: "private struct TeamScheduleEditor"))
        let editorSource = source[editor.lowerBound...]

        #expect(editorSource.contains("viewModel.scheduleDraft = nil") == false)
        #expect(editorSource.contains("Binding($viewModel.scheduleDraft)") == false)
        #expect(editorSource.contains("@State private var draft: TeamScheduleDraft"))
        #expect(editorSource.contains("dismiss()"))
    }

    @Test
    func emptyShiftListDoesNotReuseTheScheduleEmptyMessage() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.components(separatedBy: "team.view.schedule.empty").count - 1 == 1)
    }

    @Test @MainActor
    func monthNamesFollowTheAppLanguageInsteadOfTheDeviceRegion() {
        var englishDeviceCalendar = Calendar(identifier: .gregorian)
        englishDeviceCalendar.locale = Locale(identifier: "en_US")
        #expect(englishDeviceCalendar.monthSymbols[7] == "August")

        #expect(DPYearMonthPickerLocalization.monthName(8, locale: .korean) == "8월")
        #expect(DPYearMonthPickerLocalization.monthName(8, locale: .english) == "August")
    }

    @Test @MainActor
    func weekdayNamesFollowTheAppLanguageInsteadOfTheDeviceRegion() {
        var englishDeviceCalendar = Calendar(identifier: .gregorian)
        englishDeviceCalendar.locale = Locale(identifier: "en_US")
        #expect(englishDeviceCalendar.shortStandaloneWeekdaySymbols.first == "Sun")

        #expect(TeamLocalization.shortStandaloneWeekdaySymbols(locale: .korean).first == "일")
        #expect(TeamLocalization.shortStandaloneWeekdaySymbols(locale: .english).first == "Sun")
    }

    @Test
    func teamAdminToolPermissionIncludesServiceAdminAndTeamRoles() {
        let team = managedTeam(
            adminID: 1,
            members: [
                TeamMemberDTO(
                    id: 2,
                    name: "Manager",
                    email: nil,
                    isManager: true,
                    isAdmin: false,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                ),
                TeamMemberDTO(
                    id: 3,
                    name: "Member",
                    email: nil,
                    isManager: false,
                    isAdmin: false,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                )
            ]
        )

        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: nil,
                team: team,
                isServiceAdmin: true
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 1,
                team: team,
                isServiceAdmin: false
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 2,
                team: team,
                isServiceAdmin: false
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 3,
                team: team,
                isServiceAdmin: false
            ) == false
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: nil,
                team: nil,
                isServiceAdmin: false
            ) == false
        )
    }

    @Test @MainActor
    func resetLeadConfirmationNamesTheCurrentLeadInEachAppLanguage() {
        #expect(
            TeamManageConfirmationCopy.resetAdminMessage(name: "테스트 관리자", locale: .korean)
                == "테스트 관리자 님의 팀 대표 권한을 초기화하시겠습니까?"
        )
        #expect(
            TeamManageConfirmationCopy.resetAdminMessage(name: "Test Admin", locale: .english)
                == "Remove Test Admin as the team lead?"
        )
    }

    @Test
    func resolvesTheCurrentLeadNameFromPayloadThenMemberFallback() {
        let members = [
            TeamMemberDTO(
                id: 1,
                name: "Member Lead",
                email: nil,
                isManager: true,
                isAdmin: true,
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            )
        ]

        #expect(
            TeamManageConfirmationCopy.currentAdminName(
                adminName: "Payload Lead",
                adminID: 1,
                members: members,
                fallback: "N/A"
            ) == "Payload Lead"
        )
        #expect(
            TeamManageConfirmationCopy.currentAdminName(
                adminName: "  ",
                adminID: 1,
                members: members,
                fallback: "N/A"
            ) == "Member Lead"
        )
        #expect(
            TeamManageConfirmationCopy.currentAdminName(
                adminName: nil,
                adminID: nil,
                members: members,
                fallback: "N/A"
            ) == "N/A"
        )
    }

    @Test @MainActor
    func reportsManagementMutationFailureWithoutLosingRetryState() async {
        TeamURLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )

        let succeeded = await viewModel.removeMember(3)

        #expect(succeeded == false)
        #expect(viewModel.showsError)
        #expect(viewModel.showsSuccess == false)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func reportsManagementMutationSuccessWithoutRefreshingTeam() async {
        TeamURLProtocolStub.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("DELETE", "/api/teams/manage/7/members"):
                Self.response(request, status: 204)
            case ("GET", "/api/teams/manage/7"):
                Self.response(
                    request,
                    status: 200,
                    body: #"{"id":7,"name":"Team","description":null,"dutyTypes":[],"members":[],"createdDate":"2026-08-12T00:00:00","lastModifiedDate":"2026-08-12T00:00:00","adminId":null,"adminName":null,"dutyBatchTemplate":null}"#
                )
            default:
                Self.response(request, status: 404)
            }
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )
        await viewModel.load()

        let succeeded = await viewModel.removeMember(3)

        #expect(succeeded)
        #expect(viewModel.team?.id == 7)
        #expect(viewModel.showsError == false)
        #expect(viewModel.showsSuccess)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func addingAMemberPatchesTheManagementSnapshotWithoutReloading() async {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )
        await viewModel.load()
        TeamURLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }
        let candidate = MemberInviteCandidateDTO(
            id: 9,
            name: "New member",
            email: "new@example.com",
            teamId: nil,
            team: nil,
            hasProfilePhoto: true,
            profilePhotoVersion: 4
        )

        viewModel.appendMember(candidate)

        let added = viewModel.team?.members.first { $0.id == 9 }
        #expect(added?.name == "New member")
        #expect(added?.isManager == false)
        #expect(added?.isAdmin == false)
        #expect(added?.profilePhotoVersion == 4)
        TeamURLProtocolStub.handler = nil
    }

    @Test
    func memberSearchDismissDoesNotReloadTheManagementScreen() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamManageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("didAdd: { viewModel.appendMember($0) }"))
        #expect(source.contains("onDismiss: {\n            Task { await viewModel.load() }") == false)
    }

    @Test
    func existingTeamContentIsNotReplacedByAFullScreenLoadingState() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("if viewModel.isLoading && viewModel.team == nil"))
        #expect(source.contains("else if viewModel.loadFailed && viewModel.team == nil"))
    }

    @Test @MainActor
    func repeatedLoadAndMonthNavigationPreserveTheSelectedDay() async throws {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamViewModel(
            repository: TeamRepository(client: makeClient()),
            now: try #require(Self.date(year: 2026, month: 8, day: 1))
        )

        await viewModel.load(memberID: 1)
        await viewModel.selectDay(at: 1)
        #expect(viewModel.selectedDay?.day == 13)

        await viewModel.load(memberID: 1)
        #expect(viewModel.selectedDay?.day == 13)

        await viewModel.nextMonth()
        #expect(viewModel.year == 2026)
        #expect(viewModel.month == 9)
        #expect(viewModel.selectedDay?.year == 2026)
        #expect(viewModel.selectedDay?.month == 9)
        #expect(viewModel.selectedDay?.day == 13)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func managementMutationPatchesTheLoadedTeamWithoutARefreshRequest() async {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )
        await viewModel.load()
        #expect(viewModel.team?.members.contains { $0.id == 3 } == true)

        TeamURLProtocolStub.handler = { request in
            if request.httpMethod == "DELETE",
               request.url?.path == "/api/teams/manage/7/members" {
                return Self.response(request, status: 204)
            }
            return Self.response(request, status: 503)
        }

        let succeeded = await viewModel.removeMember(3)

        #expect(succeeded)
        #expect(viewModel.team?.members.contains { $0.id == 3 } == false)
        #expect(viewModel.showsError == false)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func resettingTeamAdminClearsTheLocalAdminWithoutARefreshRequest() async {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )
        await viewModel.load()
        TeamURLProtocolStub.handler = { request in
            if request.httpMethod == "PUT", request.url?.path == "/api/teams/manage/7/admin" {
                return Self.response(request, status: 204)
            }
            return Self.response(request, status: 503)
        }

        let succeeded = await viewModel.changeAdmin(memberID: nil)

        #expect(succeeded)
        #expect(viewModel.team?.adminId == nil)
        #expect(viewModel.team?.adminName == nil)
        #expect(viewModel.team?.members.first { $0.id == 1 }?.isAdmin == false)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func scheduleMutationsPatchTheLoadedMonthWithoutARefreshRequest() async throws {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamViewModel(
            repository: TeamRepository(client: makeClient()),
            now: try #require(Self.date(year: 2026, month: 8, day: 1))
        )
        await viewModel.load(memberID: 1)
        let date = try #require(Self.date(year: 2026, month: 8, day: 12))
        viewModel.scheduleDraft = TeamScheduleDraft(
            id: nil,
            content: "Local schedule",
            description: "No refresh",
            startDate: date,
            endDate: date
        )
        let scheduleID = UUID(uuidString: "B4F66F4B-95C2-4E52-B9BA-8840185C8843")!
        TeamURLProtocolStub.handler = { request in
            if request.httpMethod == "POST", request.url?.path == "/api/teams/schedules" {
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":"B4F66F4B-95C2-4E52-B9BA-8840185C8843","teamId":7,"content":"Local schedule","description":"No refresh","position":0,"year":2026,"month":8,"dayOfMonth":12,"daysFromStart":null,"totalDays":null,"startDateTime":"2026-08-12T00:00:00","endDateTime":"2026-08-12T23:59:59","createMember":"Manager","updateMember":"Manager","curDate":"2026-08-12"}"#
                )
            }
            return Self.response(request, status: 503)
        }

        await viewModel.saveSchedule()

        let saved = try #require(viewModel.selectedSchedules.first)
        #expect(saved.id == scheduleID)
        #expect(saved.content == "Local schedule")
        #expect(viewModel.scheduleDraft == nil)
        #expect(viewModel.showsError == false)

        viewModel.schedulePendingDeletion = saved
        TeamURLProtocolStub.handler = { request in
            if request.httpMethod == "DELETE",
               request.url?.path == "/api/teams/schedules/\(scheduleID.uuidString)" {
                return Self.response(request, status: 204)
            }
            return Self.response(request, status: 503)
        }

        await viewModel.deleteSchedule()

        #expect(viewModel.selectedSchedules.isEmpty)
        #expect(viewModel.schedulePendingDeletion == nil)
        #expect(viewModel.showsError == false)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func preservesLoadFailureUntilSuccessfulNoTeamResponse() async {
        TeamURLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }
        let viewModel = TeamViewModel(repository: TeamRepository(client: makeClient()))

        await viewModel.load(memberID: 1)

        #expect(viewModel.loadFailed)
        #expect(viewModel.team == nil)

        TeamURLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/calendar":
                Self.response(request, status: 200, body: "[]")
            case "/api/teams/my":
                Self.response(
                    request,
                    status: 200,
                    body: #"{"year":2026,"month":8,"team":null,"teamDays":[],"isTeamManager":false}"#
                )
            default:
                Self.response(request, status: 404)
            }
        }

        await viewModel.load(memberID: 1)

        #expect(viewModel.loadFailed == false)
        #expect(viewModel.team == nil)
        TeamURLProtocolStub.handler = nil
    }

    @Test
    func findsVisibleDutyTypeNeighborAcrossHiddenRows() {
        let dutyTypes = [
            dutyType(id: nil, hidden: false),
            dutyType(id: 1, hidden: false),
            dutyType(id: 2, hidden: true),
            dutyType(id: 3, hidden: false)
        ]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 1,
                direction: 1
            ) == 3
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 3,
                direction: -1
            ) == 1
        )
    }

    @Test
    func excludesDefaultAndHiddenDutyTypesFromReorderTargets() {
        let dutyTypes = [
            dutyType(id: nil, hidden: false),
            dutyType(id: 1, hidden: true),
            dutyType(id: 2, hidden: false),
            dutyType(id: 3, hidden: true)
        ]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 2,
                direction: -1
            ) == nil
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 2,
                direction: 1
            ) == nil
        )
    }

    @Test
    func returnsNoNeighborForInvalidIndexesOrDirection() {
        let dutyTypes = [dutyType(id: 1, hidden: false)]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: -1,
                direction: 1
            ) == nil
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 0,
                direction: 0
            ) == nil
        )
    }

    @Test
    func buildsDutyUploadMultipartBody() {
        let boundary = "Dutypark-Test-Boundary"
        let fileData = Data([0x00, 0x41, 0xFF, 0x42])
        let form = TeamMultipartForm(boundary: boundary)

        let body = form.makeBody(
            fileName: "roster.xlsx",
            fileData: fileData,
            year: 2026,
            month: 8
        )
        let text = String(decoding: body, as: UTF8.self)

        #expect(form.contentType == "multipart/form-data; boundary=\(boundary)")
        #expect(text.contains("name=\"year\"\r\n\r\n2026\r\n"))
        #expect(text.contains("name=\"month\"\r\n\r\n8\r\n"))
        #expect(
            text.contains(
                "name=\"file\"; filename=\"roster.xlsx\"\r\n"
                    + "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
        )
        #expect(body.range(of: fileData) != nil)
        #expect(body.suffix(Data("\r\n--\(boundary)--\r\n".utf8).count) == Data("\r\n--\(boundary)--\r\n".utf8))
    }

    @Test
    func decodesJacksonPairObjectInTeamBatchResult() throws {
        let result = try JSONDecoder().decode(
            TeamBatchResultDTO.self,
            from: Data(
                #"""
                {
                  "result": true,
                  "errorDetails": {"year": 2026, "month": 8},
                  "startDate": "2026-08-01",
                  "endDate": "2026-08-31",
                  "dutyBatchResult": [
                    {
                      "first": "Alice",
                      "second": {
                        "result": true,
                        "errorDetails": {"sheet": "August"},
                        "startDate": "2026-08-01",
                        "endDate": "2026-08-31",
                        "workingDays": 20,
                        "offDays": 11
                      }
                    }
                  ]
                }
                """#.utf8
            )
        )

        #expect(result.dutyBatchResult.count == 1)
        #expect(result.errorDetails?["year"] == .integer(2026))
        #expect(result.dutyBatchResult.first?.memberName == "Alice")
        #expect(result.dutyBatchResult.first?.result.result == true)
        #expect(result.dutyBatchResult.first?.result.workingDays == 20)
        #expect(result.dutyBatchResult.first?.result.offDays == 11)
        #expect(result.dutyBatchResult.first?.result.errorDetails?["sheet"] == .string("August"))
    }

    @Test
    func decodesTupleArrayInTeamBatchResult() throws {
        let result = try JSONDecoder().decode(
            TeamBatchResultDTO.self,
            from: Data(
                #"""
                {
                  "result": true,
                  "startDate": "2026-08-01",
                  "endDate": "2026-08-31",
                  "dutyBatchResult": [
                    [
                      "Bob",
                      {
                        "result": false,
                        "errorCode": "dutyBatch.nameNotFound",
                        "errorDetails": {"name": "Bob"},
                        "startDate": null,
                        "endDate": null,
                        "workingDays": 0,
                        "offDays": 0
                      }
                    ]
                  ]
                }
                """#.utf8
            )
        )

        #expect(result.dutyBatchResult.count == 1)
        #expect(result.dutyBatchResult.first?.memberName == "Bob")
        #expect(result.dutyBatchResult.first?.result.result == false)
        #expect(result.dutyBatchResult.first?.result.errorCode == "dutyBatch.nameNotFound")
        #expect(result.dutyBatchResult.first?.result.errorDetails?["name"] == .string("Bob"))
        #expect(result.dutyBatchResult.first?.result.startDate == nil)
    }

    @Test
    func validatesTeamScheduleDraft() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        #expect(schedule(content: "Team meeting", start: start, end: end).isValid)
        #expect(schedule(content: "   \n", start: start, end: end).isValid == false)
        #expect(schedule(content: String(repeating: "a", count: 51), start: start, end: end).isValid == false)
        #expect(schedule(content: "Team meeting", start: end, end: start).isValid == false)
        #expect(schedule(content: "Team meeting", start: start, end: start).isValid)
    }

    @Test
    func validatesWebParityDutyBatchInputs() {
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.xlsx"))
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("DUTY.XLSX"))
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.xls") == false)
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.csv") == false)

        #expect(TeamFeatureLogic.isValidDutyBatchYear(2026, currentYear: 2026))
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2027, currentYear: 2026))
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2025, currentYear: 2026) == false)
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2028, currentYear: 2026) == false)
    }

    @Test
    func limitsAndNormalizesDutyNamesForCompactEditor() {
        #expect(TeamManageModalLogic.limitedDutyName("12345678901") == "1234567890")
        #expect(TeamManageModalLogic.normalizedDutyName("  Day  ") == "Day")
        #expect(TeamManageModalLogic.normalizedDutyName("          Day") == "")
    }

    @Test
    func choosesTeamModalDismissBehaviorForPristineDirtyAndBusyStates() {
        #expect(TeamModalInteractionState().dismissDecision == .dismiss)
        #expect(TeamModalInteractionState(isDirty: true).dismissDecision == .confirmDiscard)
        #expect(
            TeamModalInteractionState(isDirty: true, isWorking: true).dismissDecision == .blocked
        )
    }

    @Test
    func closesConfirmationOnlyAfterSuccessfulRequest() {
        #expect(TeamManageModalLogic.shouldDismissConfirmation(didSucceed: true))
        #expect(TeamManageModalLogic.shouldDismissConfirmation(didSucceed: false) == false)
    }

    @Test
    func blocksDuplicateTeamConfirmationSubmissionsWhileWorkIsInFlight() {
        #expect(TeamConfirmationSubmissionPolicy.canSubmit(isSubmitting: false, isWorking: false))
        #expect(!TeamConfirmationSubmissionPolicy.canSubmit(isSubmitting: true, isWorking: false))
        #expect(!TeamConfirmationSubmissionPolicy.canSubmit(isSubmitting: false, isWorking: true))
    }

    @Test
    func dutyTypeVisibilityActionsUseTheCentralConfirmationFlow() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamManageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("present(.setDutyTypeVisibility(dutyType))"))
        #expect(source.contains("Task { await viewModel.toggleVisibility(dutyType) }") == false)
        #expect(source.contains("case .setDutyTypeVisibility(let dutyType):"))
        #expect(source.contains("team.dutyType.messages.hideConfirm"))
        #expect(source.contains("team.dutyType.messages.restoreConfirm"))
        #expect(source.contains("await viewModel.toggleVisibility(dutyType)"))
    }

    @Test
    func teamManagementConfirmationsUseTheCenteredSharedPanel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamManageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("TeamActionConfirmationModal"))
        #expect(!source.contains(".confirmationDialog("))
        #expect(source.components(separatedBy: ".alert(").count - 1 == 4)
        #expect(source.contains("DPConfirmationPanel("))
        #expect(source.contains("dpConfirmation("))
    }

    @Test
    func bothTeamModalsShareASingleDiscardConfirmation() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamManageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.components(separatedBy: "team.modal.discard.title").count - 1 == 1)
        #expect(source.components(separatedBy: "team.modal.discard.continue").count - 1 == 1)
        #expect(
            source.components(separatedBy: ".teamDiscardConfirmation(isPresented:").count - 1 == 2
        )
    }

    @Test @MainActor
    func dutyTypeVisibilityConfirmationMutatesLocallyWithOneRequestPerConfirmation() async throws {
        TeamURLProtocolStub.handler = { request in
            Self.successfulTeamLoadResponse(request)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )
        await viewModel.load()
        TeamURLProtocolStub.visibilityRequestCount = 0
        TeamURLProtocolStub.handler = { request in
            if request.httpMethod == "PATCH",
               request.url?.path == "/api/teams/manage/7/duty-types/11/visibility" {
                TeamURLProtocolStub.visibilityRequestCount += 1
                return Self.response(request, status: 204)
            }
            return Self.response(request, status: 503)
        }

        let visibleDuty = try #require(viewModel.team?.dutyTypes.first { $0.id == 11 })
        let didHide = await viewModel.toggleVisibility(visibleDuty)

        #expect(didHide)
        #expect(TeamURLProtocolStub.visibilityRequestCount == 1)
        #expect(viewModel.team?.dutyTypes.first { $0.id == 11 }?.hidden == true)
        let hiddenDuty = try #require(viewModel.team?.dutyTypes.first { $0.id == 11 })
        let didRestore = await viewModel.toggleVisibility(hiddenDuty)

        #expect(didRestore)
        #expect(TeamURLProtocolStub.visibilityRequestCount == 2)
        #expect(viewModel.team?.dutyTypes.first { $0.id == 11 }?.hidden == false)
        TeamURLProtocolStub.handler = nil
        TeamURLProtocolStub.visibilityRequestCount = 0
    }

    @Test
    func detectsDuplicateDutyNamesWhileExcludingEditedRow() {
        let defaultDuty = DutyTypeDTO(
            id: nil,
            teamId: 7,
            name: "Off",
            position: -1,
            color: "#FFB3BA",
            hidden: false
        )
        let day = dutyType(id: 1, hidden: false)
        let night = DutyTypeDTO(
            id: 2,
            teamId: 7,
            name: "Night",
            position: 2,
            color: "#112233",
            hidden: false
        )
        let dutyTypes = [defaultDuty, day, night]

        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                "Night",
                editingID: 1,
                editingDefaultDuty: false,
                dutyTypes: dutyTypes
            )
        )
        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                day.name,
                editingID: 1,
                editingDefaultDuty: false,
                dutyTypes: dutyTypes
            ) == false
        )
        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                "Off",
                editingID: nil,
                editingDefaultDuty: true,
                dutyTypes: dutyTypes
            ) == false
        )
    }

    @Test
    func identifiesMyShiftGroupByMemberID() {
        let mine = MemberPreviewDTO(
            id: 7,
            name: "Mine",
            teamId: 1,
            team: "Team",
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        let group = DutyByShiftDTO(dutyType: dutyType(id: 1, hidden: false), members: [mine])

        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: 7))
        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: 8) == false)
        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: nil) == false)
    }

    private func dutyType(id: DutyTypeID?, hidden: Bool) -> DutyTypeDTO {
        DutyTypeDTO(
            id: id,
            teamId: 7,
            name: id.map { "Duty \($0)" } ?? "Off",
            position: Int(id ?? 0),
            color: "#112233",
            hidden: hidden
        )
    }

    private func managedTeam(adminID: MemberID?, members: [TeamMemberDTO]) -> TeamDTO {
        TeamDTO(
            id: 7,
            name: "Team",
            description: nil,
            dutyTypes: [],
            members: members,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"),
            adminId: adminID,
            adminName: nil,
            dutyBatchTemplate: nil
        )
    }

    private func schedule(content: String, start: Date, end: Date) -> TeamScheduleDraft {
        TeamScheduleDraft(
            id: nil,
            content: content,
            description: "",
            startDate: start,
            endDate: end
        )
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TeamURLProtocolStub.self]
        return APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(body.utf8)
        )
    }

    private static func successfulTeamLoadResponse(
        _ request: URLRequest
    ) -> (HTTPURLResponse, Data) {
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let month = Int(components?.queryItems?.first { $0.name == "month" }?.value ?? "8") ?? 8
        let year = Int(components?.queryItems?.first { $0.name == "year" }?.value ?? "2026") ?? 2026
        switch request.url?.path {
        case "/api/calendar":
            return response(
                request,
                status: 200,
                body: "[{\"year\":\(year),\"month\":\(month),\"day\":12},{\"year\":\(year),\"month\":\(month),\"day\":13}]"
            )
        case "/api/teams/my":
            return response(
                request,
                status: 200,
                body: "{\"year\":\(year),\"month\":\(month),\"team\":\(managedTeamJSON),\"teamDays\":[],\"isTeamManager\":true}"
            )
        case "/api/teams/schedules", "/api/holidays":
            return response(request, status: 200, body: "[[],[]]")
        case "/api/duty", "/api/teams/shift":
            return response(request, status: 200, body: "[]")
        case "/api/teams/manage/7":
            return response(request, status: 200, body: managedTeamJSON)
        case "/api/duty_batch/templates":
            return response(request, status: 200, body: "[]")
        default:
            return response(request, status: 404)
        }
    }

    private static var managedTeamJSON: String {
        ##"{"id":7,"name":"Team","description":null,"dutyTypes":[{"id":null,"teamId":7,"name":"Off","position":-1,"color":"#112233","hidden":false},{"id":11,"teamId":7,"name":"Day","position":0,"color":"#445566","hidden":false}],"members":[{"id":1,"name":"Manager","email":"manager@example.com","isManager":true,"isAdmin":true,"hasProfilePhoto":false,"profilePhotoVersion":0},{"id":3,"name":"Member","email":"member@example.com","isManager":false,"isAdmin":false,"hasProfilePhoto":false,"profilePhotoVersion":0}],"createdDate":"2026-08-12T00:00:00","lastModifiedDate":"2026-08-12T00:00:00","adminId":1,"adminName":"Manager","dutyBatchTemplate":null}"##
    }

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: year, month: month, day: day)
        )
    }
}

private final class TeamURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var visibilityRequestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("TeamURLProtocolStub handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
