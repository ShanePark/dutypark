import SwiftUI

nonisolated enum GuestPublicCalendarLink {
    static func url(memberID: MemberID) -> URL {
        URL(string: "https://dutypark.o-r.kr/duty/\(memberID)")!
    }
}

struct GuestPublicCalendarView: View {
    @StateObject private var model: GuestPublicCalendarViewModel
    private let memberID: MemberID

    init(memberID: MemberID) {
        self.memberID = memberID
        _model = StateObject(wrappedValue: GuestPublicCalendarViewModel(memberID: memberID))
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
        .sheet(item: $model.selectedDay) { day in
            GuestCalendarDayDetailView(day: day)
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
            Text(GuestLocalization.format("guest.calendar.month.format", model.year, model.month))
                .font(.title3.bold())
                .foregroundStyle(DPColor.textPrimary)
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
                    .onTapGesture { model.selectedDay = day }
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let duty = day.duty {
                    Section {
                        LabeledContent(
                            GuestLocalization.text("guest.calendar.duty"),
                            value: duty.dutyType ?? GuestLocalization.text("guest.calendar.off")
                        )
                    } header: {
                        Text(GuestLocalization.text("guest.calendar.duty"))
                    }
                }
                if !day.holidays.isEmpty {
                    Section {
                        ForEach(Array(day.holidays.enumerated()), id: \.offset) { _, holiday in
                            Text(holiday.dateName)
                        }
                    } header: {
                        Text(GuestLocalization.text("guest.calendar.holidays"))
                    }
                }
                Section {
                    if day.schedules.isEmpty {
                        Text("guest.calendar.schedule.empty", tableName: "Guest")
                            .foregroundStyle(DPColor.textMuted)
                    }
                    ForEach(day.schedules, id: \.id) { schedule in
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            Text(schedule.content)
                                .foregroundStyle(DPColor.textPrimary)
                            if !schedule.description.isEmpty {
                                Text(schedule.description)
                                    .font(.subheadline)
                                    .foregroundStyle(DPColor.textSecondary)
                            }
                            Text(guestScheduleTime(schedule))
                                .font(.caption)
                                .foregroundStyle(DPColor.textMuted)
                            if !schedule.attachments.isEmpty {
                                GuestScheduleAttachments(schedule: schedule)
                            }
                        }
                    }
                } header: {
                    Text(GuestLocalization.text("guest.calendar.schedules"))
                }
                if !day.dDays.isEmpty {
                    Section {
                        ForEach(day.dDays, id: \.id) { item in
                            LabeledContent(item.title, value: guestDDayLabel(item))
                        }
                    } header: {
                        Text(GuestLocalization.text("guest.calendar.dday.title"))
                    }
                }
            }
            .navigationTitle(day.cell.date.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(GuestLocalization.text("guest.close")) { dismiss() }
                }
            }
        }
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
