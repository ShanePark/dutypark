import Foundation

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var schedules: [Schedule] = []
    @Published var schedulesByDay: [Int: [Schedule]] = [:]
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchResults: [Schedule] = []
    @Published var isSearching = false
    @Published var friends: [Friend] = []

    private let calendar = Calendar.current

    init() {
        let now = Date()
        selectedYear = calendar.component(.year, from: now)
        selectedMonth = calendar.component(.month, from: now)
    }

    func loadSchedules() async {
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.request(
                .schedules(year: selectedYear, month: selectedMonth),
                responseType: ScheduleListResponse.self
            )
            schedules = response.schedules

            // Group schedules by day
            var byDay: [Int: [Schedule]] = [:]
            for schedule in response.schedules {
                if byDay[schedule.dayOfMonth] == nil {
                    byDay[schedule.dayOfMonth] = []
                }
                byDay[schedule.dayOfMonth]?.append(schedule)
            }
            schedulesByDay = byDay
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadSchedules(for date: Date) async {
        selectedYear = calendar.component(.year, from: date)
        selectedMonth = calendar.component(.month, from: date)
        await loadSchedules()
    }

    func loadFriends() async {
        do {
            friends = try await APIClient.shared.request(.friends, responseType: [Friend].self)
        } catch {
            print("Failed to load friends: \(error)")
        }
    }

    func createSchedule(
        content: String,
        description: String?,
        date: Date,
        startTime: Date?,
        endTime: Date?,
        visibility: CalendarVisibility,
        taggedFriendIds: [Int],
        attachmentSessionId: String? = nil,
        orderedAttachmentIds: [String]? = nil
    ) async -> Bool {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        let startDateTime = buildDateTime(date: date, time: startTime)
        let endDateTime = buildDateTime(date: date, time: endTime)

        let request = CreateScheduleRequest(
            content: content,
            description: description,
            year: year,
            month: month,
            dayOfMonth: day,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            visibility: visibility.rawValue,
            taggedMemberIds: taggedFriendIds.isEmpty ? nil : taggedFriendIds,
            attachmentSessionId: attachmentSessionId,
            orderedAttachmentIds: orderedAttachmentIds
        )

        do {
            _ = try await APIClient.shared.request(
                .createSchedule(request: request),
                responseType: Schedule.self
            )
            await loadSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateSchedule(
        id: String,
        content: String,
        description: String?,
        date: Date,
        startTime: Date?,
        endTime: Date?,
        visibility: CalendarVisibility,
        taggedFriendIds: [Int],
        attachmentSessionId: String? = nil,
        orderedAttachmentIds: [String]? = nil
    ) async -> Bool {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        let startDateTime = buildDateTime(date: date, time: startTime)
        let endDateTime = buildDateTime(date: date, time: endTime)

        let request = UpdateScheduleRequest(
            content: content,
            description: description,
            year: year,
            month: month,
            dayOfMonth: day,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            visibility: visibility.rawValue,
            taggedMemberIds: taggedFriendIds.isEmpty ? nil : taggedFriendIds,
            attachmentSessionId: attachmentSessionId,
            orderedAttachmentIds: orderedAttachmentIds
        )

        do {
            _ = try await APIClient.shared.request(
                .updateSchedule(id: id, request: request),
                responseType: Schedule.self
            )
            await loadSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteSchedule(_ schedule: Schedule) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteSchedule(id: schedule.id))
            schedules.removeAll { $0.id == schedule.id }
            // Also update schedulesByDay
            for (day, daySchedules) in schedulesByDay {
                schedulesByDay[day] = daySchedules.filter { $0.id != schedule.id }
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func searchSchedules(memberId: Int, query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            let response: PageResponse<Schedule> = try await APIClient.shared.request(
                .searchSchedules(memberId: memberId, query: query),
                responseType: PageResponse<Schedule>.self
            )
            searchResults = response.content
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func tagFriend(scheduleId: String, friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.tagFriend(scheduleId: scheduleId, friendId: friendId))
            await loadSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func untagFriend(scheduleId: String, friendId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.untagFriend(scheduleId: scheduleId, friendId: friendId))
            await loadSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func previousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        Task { await loadSchedules() }
    }

    func nextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        Task { await loadSchedules() }
    }

    // MARK: - Attachment Management

    func createAttachmentSession(targetContextId: String? = nil) async -> String? {
        let request = CreateSessionRequest(
            contextType: AttachmentContextType.schedule.rawValue,
            targetContextId: targetContextId
        )

        do {
            let response = try await APIClient.shared.request(
                .createAttachmentSession(request: request),
                responseType: CreateSessionResponse.self
            )
            return response.sessionId
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func uploadAttachment(sessionId: String, imageData: Data, fileName: String) async -> AttachmentDto? {
        do {
            let attachment = try await APIClient.shared.uploadAttachment(
                sessionId: sessionId,
                fileData: imageData,
                fileName: fileName,
                mimeType: "image/jpeg"
            )
            return attachment
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteAttachmentSession(_ sessionId: String) async {
        do {
            try await APIClient.shared.requestVoid(.deleteAttachmentSession(sessionId: sessionId))
        } catch {
            print("Failed to delete attachment session: \(error)")
        }
    }

    private func buildDateTime(date: Date, time: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        if let time = time {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let timeString = timeFormatter.string(from: time)
            return "\(dateString)T\(timeString)"
        } else {
            return "\(dateString)T00:00:00"
        }
    }
}
