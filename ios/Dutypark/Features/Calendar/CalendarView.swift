import SwiftUI
import UniformTypeIdentifiers

struct CalendarView: View {
    @StateObject private var model: CalendarViewModel
    @State private var showsSearch = false
    @State private var showsDDayEditor = false
    @State private var showsPattern = false
    @State private var showsBatchUpdate = false
    @State private var showsMonthPicker = false
    @State private var showsDutyComparison = false
    @State private var importsDutyBatch = false

    init(memberID: MemberID? = nil, date: DateOnly? = nil, scheduleID: ScheduleID? = nil) {
        _model = StateObject(wrappedValue: CalendarViewModel(memberID: memberID, date: date, scheduleID: scheduleID))
    }

    var body: some View {
        Group {
            if model.isLoading && model.days.isEmpty {
                DPLoadingState(label: LocalizedStringKey(CalendarLocalization.text("calendar.loading")))
            } else if let error = model.errorMessage, model.days.isEmpty {
                DPErrorState(
                    title: LocalizedStringKey(CalendarLocalization.text("calendar.error.title")),
                    message: LocalizedStringKey(error),
                    retryTitle: LocalizedStringKey(CalendarLocalization.text("calendar.retry")),
                    retryAction: { Task { await model.load() } }
                )
            } else {
                calendarContent
            }
        }
        .background(DPColor.backgroundPrimary)
        .task { if model.days.isEmpty { await model.load() } }
        .sheet(item: $model.selectedDay) { day in
            DayDetailView(model: model, day: day)
        }
        .sheet(isPresented: $showsSearch) { ScheduleSearchView(model: model) }
        .sheet(isPresented: $showsDDayEditor) { DDayEditorView(model: model, existing: nil) }
        .sheet(isPresented: $showsPattern) { DutyPatternView(model: model) }
        .sheet(isPresented: $showsMonthPicker) { YearMonthPickerView(model: model) }
        .sheet(isPresented: $showsDutyComparison) { DutyComparisonView(model: model) }
        .confirmationDialog(CalendarLocalization.text("calendar.duty.batch.title"), isPresented: $showsBatchUpdate, titleVisibility: .visible) {
            ForEach(model.visibleDutyTypes, id: \.id) { type in
                Button(type.name) { Task { await model.batchUpdateDuty(dutyTypeID: type.id) } }
            }
        } message: {
            Text("calendar.duty.batch.warning", tableName: "Calendar")
        }
        .alert(CalendarLocalization.text("calendar.error.title"), isPresented: Binding(
            get: { model.errorMessage != nil && !model.days.isEmpty },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .fileImporter(isPresented: $importsDutyBatch, allowedContentTypes: dutyBatchContentTypes) { result in
            if case .success(let url) = result { Task { await model.uploadDutyBatch(url: url) } }
        }
        .alert(CalendarLocalization.text("calendar.duty.excel.title"), isPresented: Binding(
            get: { model.dutyBatchMessage != nil }, set: { if !$0 { model.dutyBatchMessage = nil } }
        )) { Button(CalendarLocalization.text("calendar.ok"), role: .cancel) { model.dutyBatchMessage = nil } } message: { Text(model.dutyBatchMessage ?? "") }
        .toolbar {
            if let memberID = model.targetMemberID {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: CalendarPublicLink.url(memberID: memberID)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(CalendarLocalization.text("calendar.share"))
                    .accessibilityIdentifier("calendar.share")
                }
            }
        }
    }

    private var calendarContent: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.medium) {
                memberPicker
                monthControls
                actionBar
                dutySummary
                calendarGrid
                dDaySection
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.bottom, DPSpacing.large)
        }
        .refreshable { await model.load() }
    }

    private var memberPicker: some View {
        Menu {
            if let me = model.me, let id = me.id {
                Button(me.name) { Task { await model.selectMember(id) } }
            }
            ForEach(model.friends, id: \.id) { friend in
                Button(friend.name) { Task { await model.selectMember(friend.id) } }
            }
        } label: {
            HStack {
                Image(systemName: model.isMyCalendar ? "person.crop.circle.fill" : "person.2.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.targetName).font(.headline)
                    if !model.targetTeamName.isEmpty { Text(model.targetTeamName).font(.caption).foregroundStyle(DPColor.textMuted) }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .foregroundStyle(DPColor.textPrimary)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
        }
    }

    private var monthControls: some View {
        HStack(spacing: DPSpacing.extraSmall) {
            Button { Task { await model.changeMonth(by: -1) } } label: {
                Image(systemName: "chevron.left").frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            Spacer()
            Button { showsMonthPicker = true } label: {
                HStack(spacing: 4) {
                    Text(CalendarLocalization.format("calendar.month.format", model.year, model.month)).font(.title3.bold())
                    Image(systemName: "chevron.down").font(.caption)
                }
                .foregroundStyle(DPColor.textPrimary)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
            Spacer()
            Button { Task { await model.changeMonth(by: 1) } } label: {
                Image(systemName: "chevron.right").frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            Button(CalendarLocalization.text("calendar.today")) { Task { await model.goToToday() } }
                .font(.subheadline.bold())
                .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .foregroundStyle(DPColor.accent)
    }

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.small) {
                if model.canEdit {
                    actionButton("magnifyingglass", "calendar.search") { showsSearch = true }
                }
                if !model.isMyCalendar, let myID = model.me?.id {
                    Button {
                        Task { await model.toggleMyDutyComparison() }
                    } label: {
                        Label(CalendarLocalization.text("calendar.compare.mine"), systemImage: model.comparedMemberIDs.contains(myID) ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.bold()).padding(.horizontal, DPSpacing.small).frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.bordered).tint(DPColor.accent)
                }
                if model.isMyCalendar {
                    if !model.friends.isEmpty {
                        actionButton("person.2", "calendar.compare") { showsDutyComparison = true }
                    }
                    actionButton("calendar.badge.plus", "calendar.dday.add") { showsDDayEditor = true }
                    actionButton("repeat", "calendar.pattern") { showsPattern = true }
                    Button {
                        Task { await model.toggleTodoItems() }
                    } label: {
                        Label(CalendarLocalization.text("calendar.todo.showTodo"), systemImage: model.showTodoItems ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.bold()).padding(.horizontal, DPSpacing.small).frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.bordered).tint(DPColor.accent)
                }
                if model.canEdit && !model.visibleDutyTypes.isEmpty {
                    Button {
                        model.setQuickDutyEditing(!model.isQuickDutyEditing)
                    } label: {
                        Label(CalendarLocalization.text(model.isQuickDutyEditing ? "calendar.duty.quick.exit" : "calendar.duty.quick.start"), systemImage: model.isQuickDutyEditing ? "xmark" : "pencil.line")
                            .font(.subheadline.bold()).padding(.horizontal, DPSpacing.small).frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.bordered).tint(model.isQuickDutyEditing ? DPColor.warning : DPColor.accent)
                }
                if model.isMyCalendar && !model.visibleDutyTypes.isEmpty {
                    actionButton("square.grid.3x3", "calendar.duty.batch") { showsBatchUpdate = true }
                }
                if model.isMyCalendar && model.team?.dutyBatchTemplate != nil {
                    actionButton("doc.badge.arrow.up", "calendar.duty.excel") { importsDutyBatch = true }
                }
            }
        }
    }

    private func actionButton(_ image: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(CalendarLocalization.text(title), systemImage: image)
                .font(.subheadline.bold())
                .padding(.horizontal, DPSpacing.small)
                .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .buttonStyle(.bordered)
        .tint(DPColor.accent)
    }

    private var dutyBatchContentTypes: [UTType] {
        let extensions = CalendarFeatureLogic.normalizedFileExtensions(
            model.team?.dutyBatchTemplate?.fileExtensions ?? []
        )
        let types = extensions.compactMap {
            UTType(filenameExtension: String($0.dropFirst()))
        }
        return types.isEmpty ? [.spreadsheet] : types
    }

    private var dutySummary: some View {
        if model.isQuickDutyEditing {
            return AnyView(quickDutyBar)
        }
        let counts = Dictionary(grouping: model.days.compactMap(\.duty).filter { $0.month == model.month }, by: { $0.dutyType ?? CalendarLocalization.text("calendar.off") })
        return AnyView(ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.medium) {
                ForEach(counts.keys.sorted(), id: \.self) { name in
                    HStack(spacing: DPSpacing.extraSmall) {
                        Circle().fill(color(hex: counts[name]?.first?.dutyColor)).frame(width: 10, height: 10)
                        Text(name).foregroundStyle(DPColor.textSecondary)
                        Text("\(counts[name]?.count ?? 0)").bold().foregroundStyle(DPColor.textPrimary)
                    }
                    .font(.caption)
                }
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
        })
    }

    private var quickDutyBar: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text("calendar.duty.quick.description", tableName: "Calendar")
                .font(.caption).foregroundStyle(DPColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DPSpacing.small) {
                    Button { model.moveQuickDutyFocus(by: -1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    Text(CalendarLocalization.format("calendar.duty.quick.day", model.quickDutyDay?.cell.day ?? 1)).font(.subheadline.bold()).foregroundStyle(DPColor.warning)
                    Button { model.moveQuickDutyFocus(by: 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    Button(CalendarLocalization.text("calendar.off")) { Task { await model.applyQuickDuty(dutyTypeID: nil) } }
                        .buttonStyle(.bordered).frame(minHeight: 44)
                    ForEach(model.visibleDutyTypes, id: \.id) { type in
                        Button(type.name) { Task { await model.applyQuickDuty(dutyTypeID: type.id) } }
                            .buttonStyle(.borderedProminent).tint(color(hex: type.color)).frame(minHeight: 44)
                    }
                }
            }
        }
        .padding(DPSpacing.small)
        .background(DPColor.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(["sun", "mon", "tue", "wed", "thu", "fri", "sat"], id: \.self) { weekday in
                    Text(CalendarLocalization.text("calendar.weekday.\(weekday)"))
                        .font(.caption.bold())
                        .foregroundStyle(weekday == "sun" ? DPColor.danger : DPColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                ForEach(Array(model.days.enumerated()), id: \.element.id) { index, day in
                    CalendarDayCell(day: day, weekday: index % 7, highlighted: model.highlightedDate == day.cell.date, pinnedDDay: model.pinnedDDay)
                        .onTapGesture {
                            if model.isQuickDutyEditing { model.focusQuickDuty(on: day) }
                            else { model.selectedDay = day }
                        }
                }
            }
        }
        .background(DPColor.borderPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
    }

    private var dDaySection: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack {
                Text("calendar.dday.title", tableName: "Calendar").font(.headline)
                Spacer()
                Text("\(model.dDays.count)").foregroundStyle(DPColor.textMuted)
            }
            if model.dDays.isEmpty {
                Text("calendar.dday.empty", tableName: "Calendar")
                    .font(.subheadline).foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DPSpacing.small) {
                    ForEach(model.dDays, id: \.id) { item in
                        DDayCard(item: item, editable: model.isMyCalendar, model: model)
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }

    private func color(hex: String?) -> Color {
        guard let hex else { return DPColor.textMuted }
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x6B7280
        return Color(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

private struct YearMonthPickerView: View {
    @ObservedObject var model: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickerYear: Int

    init(model: CalendarViewModel) {
        self.model = model
        _pickerYear = State(initialValue: model.year)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DPSpacing.medium) {
                HStack {
                    Button { pickerYear -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    Spacer()
                    Text(String(pickerYear)).font(.title2.bold())
                    Spacer()
                    Button { pickerYear += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DPSpacing.small) {
                    ForEach(1...12, id: \.self) { month in
                        Button(CalendarLocalization.format("calendar.month.short", month)) {
                            Task { await model.selectYearMonth(year: pickerYear, month: month); dismiss() }
                        }
                        .buttonStyle(.bordered)
                        .tint(pickerYear == model.year && month == model.month ? DPColor.accent : DPColor.textSecondary)
                        .frame(minHeight: 44)
                    }
                }
                Spacer()
            }
            .padding(DPSpacing.medium)
            .navigationTitle(CalendarLocalization.text("calendar.month.choose"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct DutyComparisonView: View {
    @ObservedObject var model: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(CalendarLocalization.format("calendar.compare.description", 3))
                        .font(.subheadline)
                        .foregroundStyle(DPColor.textSecondary)
                }
                Section {
                    ForEach(model.friends, id: \.id) { friend in
                        let selected = model.comparedMemberIDs.contains(friend.id)
                        Button {
                            Task { await model.toggleFriendDutyComparison(friend.id) }
                        } label: {
                            HStack {
                                Text(friend.name).foregroundStyle(DPColor.textPrimary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DPColor.accent)
                                }
                            }
                            .frame(minHeight: DPSize.minimumTouchTarget)
                        }
                        .disabled(!selected && model.comparedMemberIDs.count >= 3)
                    }
                }
                Section {
                    Text(CalendarLocalization.format("calendar.compare.count", model.comparedMemberIDs.count, 3))
                        .foregroundStyle(DPColor.textMuted)
                    if !model.comparedMemberIDs.isEmpty {
                        Button(CalendarLocalization.text("calendar.compare.clear"), role: .destructive) {
                            Task { await model.clearFriendDutyComparisons() }
                        }
                        .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                }
            }
            .navigationTitle(CalendarLocalization.text("calendar.compare"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(CalendarLocalization.text("calendar.ok")) { dismiss() }
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDayContent
    let weekday: Int
    let highlighted: Bool
    let pinnedDDay: DDayDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(day.cell.day)")
                    .font(.caption.bold())
                    .foregroundStyle(day.holidays.isEmpty && weekday != 0 ? DPColor.textPrimary : DPColor.danger)
                Spacer(minLength: 0)
                if let duty = day.duty?.dutyType {
                    Text(duty.prefix(4)).font(.system(size: 9, weight: .bold))
                    if day.duty?.source == .patternPaused { Image(systemName: "pause.circle.fill").font(.system(size: 9)) }
                }
            }
            if let pinnedDDay { compactText(relativeLabel(pinnedDDay), color: DPColor.warning) }
            if let holiday = day.holidays.first { compactText(holiday.dateName, color: DPColor.danger) }
            ForEach(day.schedules.prefix(3), id: \.id) { compactText($0.content, color: DPColor.accent) }
            ForEach(day.todos.prefix(2), id: \.id) { compactText($0.title, color: $0.isOverdue ? DPColor.danger : DPColor.textSecondary) }
            ForEach(day.dDays.prefix(1), id: \.id) { compactText($0.title, color: DPColor.warning) }
            ForEach(Array(day.comparedDuties.prefix(3).enumerated()), id: \.offset) { _, item in
                compactText("\(item.name.prefix(3)) \(item.duty.dutyType ?? CalendarLocalization.text("calendar.off"))", color: DPColor.success)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(cellBackground)
        .opacity(day.cell.isCurrentMonth ? 1 : 0.45)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(highlighted ? DPColor.danger : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityLabel(day.cell.date.rawValue)
    }

    private var cellBackground: Color {
        guard let raw = day.duty?.dutyColor else { return DPColor.backgroundCard }
        let value = UInt64(raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255).opacity(0.16)
    }

    private func compactText(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9)).lineLimit(1).foregroundStyle(color).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relativeLabel(_ item: DDayDTO) -> String {
        guard let target = CalendarDateSupport.date(from: item.date), let cell = CalendarDateSupport.date(from: day.cell.date) else { return item.title }
        let difference = CalendarDateSupport.calendar.dateComponents([.day], from: cell, to: target).day ?? 0
        let label = difference == 0 ? "D-Day" : difference > 0 ? "D-\(difference)" : "D+\(-difference)"
        return "\(item.title) \(label)"
    }
}

private struct DayDetailView: View {
    @ObservedObject var model: CalendarViewModel
    let day: CalendarDayContent
    @Environment(\.dismiss) private var dismiss
    @State private var editingSchedule: ScheduleDTO?
    @State private var showsNewSchedule = false
    @State private var selectedTodo: TodoDTO?

    var body: some View {
        NavigationStack {
            List {
                if model.canEdit && !model.visibleDutyTypes.isEmpty {
                    Section(CalendarLocalization.text("calendar.duty.title")) {
                        Picker(CalendarLocalization.text("calendar.duty.title"), selection: Binding<DutyTypeID?>(
                            get: { day.duty?.dutyTypeId },
                            set: { id in Task { await model.updateDuty(day: day, dutyTypeID: id) } }
                        )) {
                            Text("calendar.off", tableName: "Calendar").tag(DutyTypeID?.none)
                            ForEach(model.visibleDutyTypes, id: \.id) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                Section {
                    if day.schedules.isEmpty {
                        Text("calendar.schedule.empty", tableName: "Calendar").foregroundStyle(DPColor.textMuted)
                    }
                    ForEach(ownedSchedules, id: \.id) { schedule in
                        Button {
                            if model.canEdit && !schedule.isTagged { editingSchedule = schedule }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(schedule.content).foregroundStyle(DPColor.textPrimary)
                                if !schedule.description.isEmpty { Text(schedule.description).font(.caption).foregroundStyle(DPColor.textSecondary).lineLimit(2) }
                                Text(scheduleTime(schedule)).font(.caption).foregroundStyle(DPColor.textMuted)
                                scheduleMetadata(schedule)
                                if !schedule.attachments.isEmpty {
                                    ScheduleAttachmentGallery(schedule: schedule, canEdit: model.canEdit && !schedule.isTagged)
                                }
                            }
                        }
                        .swipeActions {
                            if schedule.isTagged && model.isMyCalendar {
                                Button(CalendarLocalization.text("calendar.schedule.untag"), role: .destructive) { Task { await model.untagSelf(schedule) } }
                            } else if model.canEdit {
                                Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { Task { await model.deleteSchedule(schedule) } }
                            }
                        }
                    }
                    .onMove { source, destination in Task { await model.moveSchedule(from: source, to: destination, in: day) } }
                    ForEach(taggedSchedules, id: \.id) { schedule in
                        scheduleRow(schedule)
                    }
                } header: {
                    HStack {
                        Text("calendar.schedule.title", tableName: "Calendar")
                        Spacer()
                        if model.canEdit {
                            Button { showsNewSchedule = true } label: { Image(systemName: "plus.circle.fill") }
                        }
                        if model.canEdit && ownedSchedules.count > 1 { EditButton() }
                    }
                }
                if !day.todos.isEmpty {
                    Section(CalendarLocalization.text("calendar.todo.title")) {
                        ForEach(day.todos, id: \.id) { todo in
                            Button {
                                selectedTodo = todo
                            } label: {
                                Label(todo.title, systemImage: todo.status == .inProgress ? "clock" : "checklist")
                            }
                        }
                    }
                }
            }
            .navigationTitle(day.cell.date.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } } }
            .sheet(isPresented: $showsNewSchedule) { ScheduleEditorView(model: model, day: day, existing: nil) }
            .sheet(isPresented: Binding(
                get: { editingSchedule != nil },
                set: { if !$0 { editingSchedule = nil } }
            )) {
                if let editingSchedule { ScheduleEditorView(model: model, day: day, existing: editingSchedule) }
            }
            .sheet(isPresented: Binding(get: { selectedTodo != nil }, set: { if !$0 { selectedTodo = nil } })) {
                if let selectedTodo {
                    NavigationStack {
                        TodoView(
                            initialTodoID: selectedTodo.uuid,
                            onTodoChanged: { try? await model.loadMonth() }
                        )
                        .navigationTitle(CalendarLocalization.text("calendar.todo.title"))
                    }
                }
            }
        }
    }

    private func scheduleTime(_ schedule: ScheduleDTO) -> String {
        "\(schedule.startDateTime.rawValue.replacingOccurrences(of: "T", with: " ")) – \(schedule.endDateTime.rawValue.replacingOccurrences(of: "T", with: " "))"
    }

    private var ownedSchedules: [ScheduleDTO] { day.schedules.filter { !$0.isTagged } }
    private var taggedSchedules: [ScheduleDTO] { day.schedules.filter(\.isTagged) }

    private func scheduleRow(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schedule.content).foregroundStyle(DPColor.textPrimary)
            if !schedule.description.isEmpty { Text(schedule.description).font(.caption).foregroundStyle(DPColor.textSecondary).lineLimit(2) }
            Text(scheduleTime(schedule)).font(.caption).foregroundStyle(DPColor.textMuted)
            scheduleMetadata(schedule)
            if !schedule.attachments.isEmpty {
                ScheduleAttachmentGallery(schedule: schedule, canEdit: false)
            }
        }
        .swipeActions {
            if model.isMyCalendar { Button(CalendarLocalization.text("calendar.schedule.untag"), role: .destructive) { Task { await model.untagSelf(schedule) } } }
        }
    }

    private func scheduleMetadata(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if schedule.totalDays > 1 {
                Text(CalendarLocalization.format("calendar.schedule.progress", schedule.daysFromStart, schedule.totalDays)).font(.caption2).foregroundStyle(DPColor.accent)
            }
            if schedule.isTagged { Label(schedule.owner, systemImage: "person.crop.circle.badge.checkmark").font(.caption) }
            if !schedule.tags.isEmpty { Label(schedule.tags.map(\.name).joined(separator: ", "), systemImage: "tag").font(.caption2) }
            if let visibility = schedule.visibility {
                Label(CalendarLocalization.text("calendar.visibility.\(visibilityKey(visibility))"), systemImage: "eye").font(.caption2)
            }
        }
        .foregroundStyle(DPColor.textMuted)
    }

    private func visibilityKey(_ visibility: Visibility) -> String {
        switch visibility {
        case .publicAccess: "public"
        case .friends: "friends"
        case .family: "family"
        case .privateAccess: "private"
        case .unknown: "private"
        }
    }
}

private struct ScheduleEditorView: View {
    @ObservedObject var model: CalendarViewModel
    let day: CalendarDayContent
    let existing: ScheduleDTO?
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var description: String
    @State private var visibility: Visibility
    @State private var start: Date
    @State private var end: Date
    @State private var tagIDs: Set<MemberID>
    @State private var isSaving = false
    @StateObject private var attachmentModel: AttachmentPickerModel

    init(model: CalendarViewModel, day: CalendarDayContent, existing: ScheduleDTO?) {
        self.model = model; self.day = day; self.existing = existing
        let base = CalendarDateSupport.date(from: day.cell.date) ?? Date()
        let defaultEnd = CalendarDateSupport.calendar.date(byAdding: .hour, value: 1, to: base) ?? base
        _content = State(initialValue: existing?.content ?? "")
        _description = State(initialValue: existing?.description ?? "")
        _visibility = State(initialValue: existing?.visibility ?? .family)
        _start = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.startDateTime) } ?? base)
        _end = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.endDateTime) } ?? defaultEnd)
        _tagIDs = State(initialValue: Set(existing?.tags.compactMap(\.id) ?? []))
        _attachmentModel = StateObject(wrappedValue: AttachmentPickerModel(
            contextType: .schedule,
            targetContextId: existing?.id.uuidString,
            existingAttachments: existing?.attachments ?? []
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(CalendarLocalization.text("calendar.schedule.info")) {
                    TextField(CalendarLocalization.text("calendar.schedule.content"), text: $content).textInputAutocapitalization(.sentences)
                    TextField(CalendarLocalization.text("calendar.schedule.description"), text: $description, axis: .vertical).lineLimit(3...6)
                    Text("\(content.count)/50").font(.caption).foregroundStyle(content.count > 50 ? DPColor.danger : DPColor.textMuted)
                }
                Section(CalendarLocalization.text("calendar.schedule.time")) {
                    DatePicker(CalendarLocalization.text("calendar.schedule.start"), selection: $start)
                    DatePicker(CalendarLocalization.text("calendar.schedule.end"), selection: $end, in: start...)
                }
                Section(CalendarLocalization.text("calendar.schedule.visibility")) {
                    Picker(CalendarLocalization.text("calendar.schedule.visibility"), selection: $visibility) {
                        Text("calendar.visibility.public", tableName: "Calendar").tag(Visibility.publicAccess)
                        Text("calendar.visibility.friends", tableName: "Calendar").tag(Visibility.friends)
                        Text("calendar.visibility.family", tableName: "Calendar").tag(Visibility.family)
                        Text("calendar.visibility.private", tableName: "Calendar").tag(Visibility.privateAccess)
                    }
                }
                if model.isMyCalendar && !model.friends.isEmpty {
                    Section(CalendarLocalization.text("calendar.schedule.tags")) {
                        ForEach(model.friends, id: \.id) { friend in
                            Button {
                                if tagIDs.contains(friend.id) { tagIDs.remove(friend.id) } else { tagIDs.insert(friend.id) }
                            } label: {
                                HStack { Text(friend.name); Spacer(); if tagIDs.contains(friend.id) { Image(systemName: "checkmark") } }
                            }
                        }
                    }
                }
                Section {
                    AttachmentPicker(model: attachmentModel)
                }
            }
            .navigationTitle(CalendarLocalization.text(existing == nil ? "calendar.schedule.add" : "calendar.schedule.edit"))
            .interactiveDismissDisabled(interactionsDisabled)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CalendarLocalization.text("calendar.cancel")) {
                        Task {
                            if await attachmentModel.discard() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(interactionsDisabled)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CalendarLocalization.text("calendar.save")) {
                        isSaving = true
                        Task {
                            guard let attachments = await attachmentModel.resultForSave() else {
                                isSaving = false
                                return
                            }
                            if await model.saveSchedule(
                                existing: existing, content: content, description: description,
                                visibility: visibility, start: start, end: end,
                                tagFriendIDs: Array(tagIDs),
                                attachmentSessionID: attachments.attachmentSessionId,
                                orderedAttachmentIDs: attachments.orderedAttachmentIds
                            ) { dismiss() }
                            isSaving = false
                        }
                    }.disabled(interactionsDisabled || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.count > 50 || end < start)
                }
            }
        }
    }

    private var interactionsDisabled: Bool {
        ScheduleEditorInteractionPolicy.interactionsDisabled(
            isSaving: isSaving,
            isUploading: attachmentModel.isBusy
        )
    }
}

nonisolated enum ScheduleEditorInteractionPolicy {
    static func interactionsDisabled(isSaving: Bool, isUploading: Bool) -> Bool {
        isSaving || isUploading
    }
}

private struct ScheduleAttachmentGallery: View {
    let schedule: ScheduleDTO
    let canEdit: Bool
    @StateObject private var gallery: AttachmentGalleryModel

    init(schedule: ScheduleDTO, canEdit: Bool) {
        self.schedule = schedule
        self.canEdit = canEdit
        _gallery = StateObject(wrappedValue: AttachmentGalleryModel(
            contextType: .schedule,
            contextId: schedule.id.uuidString
        ))
    }

    var body: some View {
        DisclosureGroup {
            AttachmentGallery(model: gallery, canEdit: canEdit)
        } label: {
            Label("\(schedule.attachments.count)", systemImage: "paperclip")
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleSearchView: View {
    @ObservedObject var model: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                HStack {
                    TextField(CalendarLocalization.text("calendar.search.placeholder"), text: $model.searchQuery)
                        .textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit { Task { await model.search() } }
                    Button { Task { await model.search() } } label: { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }
                }
                if model.isSearching { ProgressView() }
                ForEach(Array(model.searchResults.enumerated()), id: \.offset) { _, item in
                    Button {
                        Task { await model.showSearchResult(item); dismiss() }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.content).foregroundStyle(DPColor.textPrimary)
                            Text(item.startDateTime.rawValue.replacingOccurrences(of: "T", with: " ")).font(.caption).foregroundStyle(DPColor.textMuted)
                            Text(item.author).font(.caption).foregroundStyle(DPColor.textSecondary)
                        }
                    }
                }
                if model.canLoadMoreSearchResults {
                    Button(CalendarLocalization.text("calendar.search.more")) {
                        Task { await model.loadMoreSearchResults() }
                    }
                    .disabled(model.isSearching)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
            }
            .navigationTitle(CalendarLocalization.text("calendar.search"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } } }
        }
    }
}

private struct DDayCard: View {
    let item: DDayDTO
    let editable: Bool
    @ObservedObject var model: CalendarViewModel
    @State private var edits = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { if editable { edits = true } } label: {
                    HStack {
                        Text(item.title).lineLimit(1)
                        if item.isPrivate { Image(systemName: "lock.fill").font(.caption) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button { model.togglePinnedDDay(item) } label: {
                    Image(systemName: model.pinnedDDayID == item.id ? "star.fill" : "star")
                        .foregroundStyle(DPColor.warning).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            Button { if editable { edits = true } } label: {
                VStack(alignment: .leading, spacing: 4) {
                Text(dDayLabel).font(.title3.bold()).foregroundStyle(DPColor.accent)
                Text(item.date.rawValue).font(.caption).foregroundStyle(DPColor.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(DPSpacing.small)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .sheet(isPresented: $edits) { DDayEditorView(model: model, existing: item) }
    }
    private var dDayLabel: String { item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)" }
}

private struct DDayEditorView: View {
    @ObservedObject var model: CalendarViewModel
    let existing: DDayDTO?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var isPrivate: Bool
    @State private var confirmsDelete = false

    init(model: CalendarViewModel, existing: DDayDTO?) {
        self.model = model; self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _date = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.date) } ?? Date())
        _isPrivate = State(initialValue: existing?.isPrivate ?? false)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField(CalendarLocalization.text("calendar.dday.name"), text: $title)
                DatePicker(CalendarLocalization.text("calendar.dday.date"), selection: $date, displayedComponents: .date)
                Toggle(CalendarLocalization.text("calendar.dday.private"), isOn: $isPrivate)
                HStack {
                    ForEach([-7, -1, 0, 1, 7], id: \.self) { offset in
                        Button(offset == 0 ? CalendarLocalization.text("calendar.today") : (offset > 0 ? "+\(offset)" : "\(offset)")) {
                            date = CalendarDateSupport.calendar.date(byAdding: .day, value: offset, to: offset == 0 ? Date() : date) ?? date
                        }.frame(minWidth: 44, minHeight: 44)
                    }
                }
                if existing != nil { Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { confirmsDelete = true } }
            }
            .navigationTitle(CalendarLocalization.text(existing == nil ? "calendar.dday.add" : "calendar.dday.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(CalendarLocalization.text("calendar.save")) { Task { if await model.saveDDay(existing: existing, title: title, date: date, isPrivate: isPrivate) { dismiss() } } }.disabled(title.isEmpty || title.count > 30) }
            }
            .confirmationDialog(CalendarLocalization.text("calendar.delete.confirm"), isPresented: $confirmsDelete) {
                if let existing { Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { Task { await model.deleteDDay(existing); dismiss() } } }
            }
        }
    }
}

private struct DutyPatternView: View {
    @ObservedObject var model: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selections: [Weekday: DutyTypeID?] = [:]
    @State private var holidayOff = false
    @State private var confirmsDelete = false
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        NavigationStack {
            Form {
                if let pattern = model.pattern, !pattern.configurable {
                    Text(pattern.reason ?? CalendarLocalization.text("calendar.pattern.unavailable"))
                } else {
                    if let effectiveFrom = model.pattern?.pattern?.effectiveFrom {
                        LabeledContent(CalendarLocalization.text("calendar.pattern.effectiveFrom"), value: effectiveFrom.rawValue)
                    }
                    ForEach(weekdays, id: \.rawValue) { weekday in
                        Picker(weekdayName(weekday), selection: Binding<DutyTypeID?>(
                            get: { selections[weekday] ?? nil }, set: { selections[weekday] = $0 }
                        )) {
                            Text("calendar.off", tableName: "Calendar").tag(DutyTypeID?.none)
                            if let hiddenType = hiddenSelectedType(for: weekday) {
                                Text(CalendarLocalization.format("calendar.pattern.hidden.type", hiddenType.name)).tag(DutyTypeID?.some(hiddenType.id))
                            }
                            ForEach(model.pattern?.dutyTypes ?? [], id: \.id) { type in Text(type.name).tag(DutyTypeID?.some(type.id)) }
                        }
                    }
                    Toggle(CalendarLocalization.text("calendar.pattern.holidayOff"), isOn: $holidayOff)
                    if hasHiddenSelection {
                        Section {
                            Label(CalendarLocalization.text("calendar.pattern.paused.warning"), systemImage: "pause.circle.fill")
                                .foregroundStyle(DPColor.warning)
                            Text("calendar.pattern.paused.description", tableName: "Calendar")
                                .font(.caption).foregroundStyle(DPColor.textSecondary)
                        }
                    }
                    if model.pattern?.pattern != nil { Button(CalendarLocalization.text("calendar.pattern.delete"), role: .destructive) { confirmsDelete = true } }
                }
            }
            .navigationTitle(CalendarLocalization.text("calendar.pattern"))
            .task {
                await model.loadPattern()
                holidayOff = model.pattern?.pattern?.holidayOff ?? false
                selections = Dictionary(uniqueKeysWithValues: (model.pattern?.pattern?.days ?? []).map { ($0.weekday, Optional($0.dutyType.id)) })
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CalendarLocalization.text("calendar.save")) {
                        let days = CalendarFeatureLogic.patternDays(
                            weekdays: weekdays,
                            selections: selections
                        )
                        Task { if await model.savePattern(days: days, holidayOff: holidayOff) { dismiss() } }
                    }.disabled(model.pattern?.configurable != true || selectedPatternDutyTypeIDs.isEmpty || hasHiddenSelection)
                }
            }
            .confirmationDialog(CalendarLocalization.text("calendar.pattern.delete.confirm"), isPresented: $confirmsDelete) {
                Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { Task { await model.deletePattern(); dismiss() } }
            }
        }
    }
    private func weekdayName(_ value: Weekday) -> String {
        let key: String = switch value {
        case .monday: "mon"; case .tuesday: "tue"; case .wednesday: "wed"; case .thursday: "thu"; case .friday: "fri"; case .saturday: "sat"; case .sunday: "sun"; case .unknown: ""
        }
        return CalendarLocalization.text("calendar.weekday.\(key)")
    }

    private var visiblePatternDutyTypeIDs: [DutyTypeID] { model.pattern?.dutyTypes.map(\.id) ?? [] }
    private var selectedPatternDutyTypeIDs: [DutyTypeID] { selections.values.compactMap { $0 } }
    private var hasHiddenSelection: Bool {
        !CalendarFeatureLogic.canSavePattern(
            selectedDutyTypeIDs: selectedPatternDutyTypeIDs,
            visibleDutyTypeIDs: visiblePatternDutyTypeIDs
        )
    }
    private func hiddenSelectedType(for weekday: Weekday) -> DutyPatternDutyTypeDTO? {
        guard let selectedID = selections[weekday] ?? nil,
              !visiblePatternDutyTypeIDs.contains(selectedID)
        else { return nil }
        return model.pattern?.pattern?.days.first(where: { $0.weekday == weekday && $0.dutyType.id == selectedID })?.dutyType
    }
}
