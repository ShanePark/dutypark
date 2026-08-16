import SwiftUI

nonisolated enum GuestPublicCalendarLink {
    static func url(memberID: MemberID) -> URL {
        URL(string: "https://dutypark.o-r.kr/duty/\(memberID)")!
    }
}

enum GuestCalendarLocalization {
    static func yearMonth(
        year: Int,
        month: Int,
        template: String = GuestLocalization.text("guest.calendar.month.format")
    ) -> String {
        String(
            format: template,
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: [year, month]
        )
    }
}

struct GuestPublicCalendarView: View {
    @StateObject private var model: GuestPublicCalendarViewModel
    @State private var showsMonthPicker = false
    private let memberID: MemberID

    init(memberID: MemberID) {
        self.memberID = memberID
        _model = StateObject(wrappedValue: GuestPublicCalendarViewModel(
            memberID: memberID,
            api: GuestPublicCalendarAPIProvider.make(),
            now: GuestPublicCalendarAPIProvider.now()
        ))
    }

    var body: some View {
        Group {
            if model.isLoading && model.days.isEmpty {
                ProgressView(GuestLocalization.text("guest.calendar.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.hasError && model.days.isEmpty {
                VStack(spacing: DPSpacing.medium) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(DPColor.danger)
                    Text(GuestLocalization.text("guest.calendar.error.title"))
                        .font(.headline)
                    Text(GuestLocalization.text("guest.calendar.error.message"))
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(GuestLocalization.text("guest.retry")) {
                        Task { await model.load() }
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                }
                .padding(DPSpacing.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(model.member?.name ?? GuestLocalization.text("guest.calendar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: publicURL) {
                    Label(
                        GuestLocalization.text("guest.calendar.share"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier("guest.calendar.share")
            }
        }
        .task { if model.days.isEmpty { await model.load() } }
        .refreshable { await model.load() }
        .sheet(isPresented: $showsMonthPicker) {
            DPYearMonthPicker(
                selectedYear: model.year,
                selectedMonth: model.month,
                title: Text(verbatim: GuestLocalization.text("guest.calendar.month.choose")),
                previousYearLabel: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.previousYear")
                ),
                nextYearLabel: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.nextYear")
                ),
                currentMonthTitle: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.current")
                ),
                cancelTitle: GuestLocalization.text("guest.close"),
                identifierPrefix: "guest.calendar.monthPicker",
                onSelect: { year, month in
                    showsMonthPicker = false
                    Task { await model.selectYearMonth(year: year, month: month) }
                },
                onCurrentMonth: {
                    showsMonthPicker = false
                    Task { await model.goToToday() }
                }
            )
        }
        .fullScreenCover(item: $model.selectedDay) { day in
            DPModalOverlay(
                onDismiss: { model.selectedDay = nil },
                closeOnBackdrop: false
            ) { availableSize, dismiss in
                GuestCalendarDayDetailView(
                    day: day,
                    maximumHeight: availableSize.height,
                    dismiss: dismiss
                )
            }
        }
        .alert(GuestLocalization.text("guest.calendar.error.title"), isPresented: Binding(
            get: { model.hasError && !model.days.isEmpty },
            set: { if !$0 { model.hasError = false } }
        )) {
            Button(GuestLocalization.text("guest.ok"), role: .cancel) {}
        } message: {
            Text("guest.calendar.error.message", tableName: "Guest")
        }
    }

    private var publicURL: URL {
        GuestPublicCalendarLink.url(memberID: memberID)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.medium) {
                if let member = model.member {
                    Label(member.name, systemImage: "person.crop.circle.fill")
                        .font(.headline)
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
                        .padding(.horizontal, DPSpacing.medium)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(
                            RoundedRectangle(cornerRadius: DPRadius.standard)
                                .stroke(DPColor.borderPrimary)
                        )
                }
                monthControls
                dutySummary
                calendarGrid
                dDaySection
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.bottom, DPSpacing.large)
        }
    }

    private var monthControls: some View {
        HStack(spacing: DPSpacing.extraSmall) {
            Button { Task { await model.changeMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            Spacer()
            Button {
                showsMonthPicker = true
            } label: {
                HStack(spacing: DPSpacing.extraSmall) {
                    Text(GuestCalendarLocalization.yearMonth(year: model.year, month: model.month))
                        .font(.title3.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundStyle(DPColor.textPrimary)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GuestLocalization.text("guest.calendar.month.choose"))
            .accessibilityValue(GuestCalendarLocalization.yearMonth(
                year: model.year,
                month: model.month
            ))
            .accessibilityIdentifier("guest.calendar.monthPicker.open")
            Spacer()
            Button { Task { await model.changeMonth(by: 1) } } label: {
                Image(systemName: "chevron.right")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            Button(GuestLocalization.text("guest.calendar.today")) {
                Task { await model.goToToday() }
            }
            .font(.subheadline.bold())
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .foregroundStyle(DPColor.accent)
        .disabled(model.isLoading)
    }

    private var dutySummary: some View {
        let counts = Dictionary(
            grouping: model.days.compactMap(\.duty).filter { $0.month == model.month },
            by: { $0.dutyType ?? GuestLocalization.text("guest.calendar.off") }
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.medium) {
                ForEach(counts.keys.sorted(), id: \.self) { name in
                    HStack(spacing: DPSpacing.extraSmall) {
                        Circle()
                            .fill(guestColor(hex: counts[name]?.first?.dutyColor))
                            .frame(width: 10, height: 10)
                        Text(name).foregroundStyle(DPColor.textSecondary)
                        Text("\(counts[name]?.count ?? 0)")
                            .bold()
                            .foregroundStyle(DPColor.textPrimary)
                    }
                    .font(.caption)
                }
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
            spacing: 1
        ) {
            ForEach(["sun", "mon", "tue", "wed", "thu", "fri", "sat"], id: \.self) { weekday in
                Text(GuestLocalization.text("guest.calendar.weekday.\(weekday)"))
                    .font(.caption.bold())
                    .foregroundStyle(weekday == "sun" ? DPColor.danger : DPColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            ForEach(Array(model.days.enumerated()), id: \.element.id) { index, day in
                GuestCalendarDayCell(day: day, weekday: index % 7)
                    .onTapGesture {
                        withoutPresentationAnimation { model.selectedDay = day }
                    }
            }
        }
        .background(DPColor.borderPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        )
    }

    private var dDaySection: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack {
                Text("guest.calendar.dday.title", tableName: "Guest")
                    .font(.headline)
                Spacer()
                Text("\(model.dDays.count)")
                    .foregroundStyle(DPColor.textMuted)
            }
            if model.dDays.isEmpty {
                Text("guest.calendar.dday.empty", tableName: "Guest")
                    .font(.subheadline)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: DPSpacing.small
                ) {
                    ForEach(model.dDays, id: \.id) { item in
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            Text(item.title).lineLimit(1)
                            Text(guestDDayLabel(item))
                                .font(.title3.bold())
                                .foregroundStyle(DPColor.accent)
                            Text(item.date.rawValue)
                                .font(.caption)
                                .foregroundStyle(DPColor.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .padding(DPSpacing.small)
                        .background(DPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}

private nonisolated enum GuestPublicCalendarAPIProvider {
    static func make() -> GuestAPIProtocol {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-calendar") {
            return GuestPublicCalendarUITestingAPI()
        }
#endif
        return GuestAPI()
    }

    static func now() -> Date {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-calendar"),
           let date = CalendarDateSupport.calendar.date(
               from: DateComponents(year: 2026, month: 8, day: 15)
           ) {
            return date
        }
#endif
        return Date()
    }
}

#if DEBUG
private nonisolated struct GuestPublicCalendarUITestingAPI: GuestAPIProtocol, Sendable {
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "김듀티",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        guard let firstDay = CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) else { return [] }
        let weekday = CalendarDateSupport.calendar.component(.weekday, from: firstDay)
        guard let gridStart = CalendarDateSupport.calendar.date(
            byAdding: .day,
            value: -(weekday - 1),
            to: firstDay
        ) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = CalendarDateSupport.calendar.date(
                byAdding: .day,
                value: offset,
                to: gridStart
            ) else { return nil }
            let components = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return nil
            }
            return TeamDayDTO(year: year, month: month, day: day)
        }
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] { [] }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        Array(repeating: [], count: 42)
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        Array(repeating: [], count: 42)
    }
    func dDays(memberID: MemberID) async throws -> [DDayDTO] { [] }
    func policy(_ type: PolicyType) async throws -> PolicyDTO { throw URLError(.unsupportedURL) }
}
#endif

private struct GuestCalendarDayCell: View {
    let day: GuestCalendarDay
    let weekday: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(day.cell.day)")
                    .font(.caption.bold())
                    .foregroundStyle(day.holidays.isEmpty && weekday != 0 ? DPColor.textPrimary : DPColor.danger)
                Spacer(minLength: 0)
                if let duty = day.duty?.dutyType {
                    Text(duty.prefix(4)).font(.system(size: 9, weight: .bold))
                }
            }
            if let holiday = day.holidays.first {
                compactText(holiday.dateName, color: DPColor.danger)
            }
            ForEach(day.schedules.prefix(3), id: \.id) {
                compactText($0.content, color: DPColor.accent)
            }
            ForEach(day.dDays.prefix(1), id: \.id) {
                compactText($0.title, color: DPColor.warning)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(cellBackground)
        .opacity(day.cell.isCurrentMonth ? 1 : 0.45)
        .contentShape(Rectangle())
        .accessibilityLabel(day.cell.date.rawValue)
    }

    private var cellBackground: Color {
        guard let value = day.duty?.dutyColor else { return DPColor.backgroundCard }
        return guestColor(hex: value).opacity(0.16)
    }

    private func compactText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9))
            .lineLimit(1)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GuestCalendarDayDetailView: View {
    let day: GuestCalendarDay
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            modalHeader
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                if let duty = day.duty {
                    detailSection(GuestLocalization.text("guest.calendar.duty")) {
                        HStack(spacing: DPSpacing.small) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(guestColor(hex: duty.dutyColor))
                                .frame(width: 14, height: 14)
                            Text(duty.dutyType ?? GuestLocalization.text("guest.calendar.off"))
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textPrimary)
                        }
                    }
                }

                if !day.holidays.isEmpty {
                    detailSection(GuestLocalization.text("guest.calendar.holidays")) {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            ForEach(Array(day.holidays.enumerated()), id: \.offset) { _, holiday in
                                Text(holiday.dateName)
                                    .font(DPTypography.label)
                                    .foregroundStyle(DPColor.danger)
                            }
                        }
                    }
                }

                detailSection(GuestLocalization.text("guest.calendar.schedules")) {
                    if day.schedules.isEmpty {
                        Text("guest.calendar.schedule.empty", tableName: "Guest")
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    } else {
                        VStack(alignment: .leading, spacing: DPSpacing.compact) {
                            ForEach(day.schedules, id: \.id) { schedule in
                                scheduleCard(schedule)
                            }
                        }
                    }
                }

                if !day.dDays.isEmpty {
                    detailSection(GuestLocalization.text("guest.calendar.dday.title")) {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            ForEach(day.dDays, id: \.id) { item in
                                HStack {
                                    Text(item.title)
                                        .font(DPTypography.label)
                                        .foregroundStyle(DPColor.textPrimary)
                                    Spacer()
                                    Text(guestDDayLabel(item))
                                        .font(DPTypography.label)
                                        .foregroundStyle(DPColor.accent)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var modalHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Text(formattedDate)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DPColor.textPrimary)
            .accessibilityLabel(GuestLocalization.text("guest.close"))
        }
        .padding(.leading, 14)
        .padding(.trailing, DPSpacing.extraSmall)
        .padding(.vertical, DPSpacing.extraSmall)
        .background(DPColor.backgroundTertiary)
    }

    private func scheduleCard(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(schedule.content)
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textPrimary)

            Text(guestScheduleTime(schedule))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)

            if !schedule.description.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                Text(schedule.description)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                    .textSelection(.enabled)
            }

            if !schedule.attachments.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                GuestScheduleAttachments(schedule: schedule)
            }
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(title)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: day.cell.date) else {
            return day.cell.date.rawValue
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = selectedLocale
        dateFormatter.calendar = CalendarDateSupport.calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMMdEEE")
        return dateFormatter.string(from: date)
    }

    private var selectedLocale: Locale {
        AppLocalization.locale
    }
}

private struct GuestScheduleAttachments: View {
    let schedule: ScheduleDTO
    @StateObject private var gallery: AttachmentGalleryModel

    init(schedule: ScheduleDTO) {
        self.schedule = schedule
        _gallery = StateObject(wrappedValue: AttachmentGalleryModel(
            contextType: .schedule,
            contextId: schedule.id.uuidString
        ))
    }

    var body: some View {
        DisclosureGroup {
            AttachmentGallery(model: gallery, canEdit: false)
        } label: {
            Label("\(schedule.attachments.count)", systemImage: "paperclip")
                .font(.caption)
        }
    }
}

private func guestScheduleTime(_ schedule: ScheduleDTO) -> String {
    let start = schedule.startDateTime.rawValue.replacingOccurrences(of: "T", with: " ")
    let end = schedule.endDateTime.rawValue.replacingOccurrences(of: "T", with: " ")
    return "\(start) – \(end)"
}

private func guestDDayLabel(_ item: DDayDTO) -> String {
    item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)"
}

private func guestColor(hex: String?) -> Color {
    guard let hex else { return DPColor.textMuted }
    let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x6B7280
    return Color(
        red: Double((value >> 16) & 0xff) / 255,
        green: Double((value >> 8) & 0xff) / 255,
        blue: Double(value & 0xff) / 255
    )
}
