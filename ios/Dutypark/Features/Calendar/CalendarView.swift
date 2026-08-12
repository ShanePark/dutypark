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
            LazyVStack(spacing: DPSpacing.small) {
                calendarHeader
                dutyToolbar
                calendarGrid
                dDaySection
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.top, DPSpacing.extraSmall)
            .padding(.bottom, DPSpacing.large)
        }
        .refreshable { await model.load() }
    }

    private var calendarHeader: some View {
        HStack(spacing: 2) {
            memberPicker
                .frame(maxWidth: .infinity, alignment: .leading)
            monthControls
                .fixedSize(horizontal: true, vertical: false)
            Group {
                if model.canSearchSchedules {
                    searchControl
                } else {
                    Color.clear
                        .frame(width: 82, height: 42)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
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
            HStack(spacing: 6) {
                Circle()
                    .fill(DPColor.backgroundTertiary)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text(model.targetName.prefix(1).uppercased())
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .foregroundStyle(DPColor.textSecondary)
                    }
                Text(model.targetName)
                    .font(DPFont.bold(size: 12, relativeTo: .caption))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var monthControls: some View {
        HStack(spacing: 0) {
            Button { Task { await model.changeMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            Button { showsMonthPicker = true } label: {
                Text(String(format: "%04d-%02d", model.year, model.month))
                    .font(DPFont.bold(size: 16, relativeTo: .headline))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: 88)
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            Button { Task { await model.changeMonth(by: 1) } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
        }
        .foregroundStyle(DPColor.accent)
    }

    private var searchControl: some View {
        HStack(spacing: 0) {
            TextField(CalendarLocalization.text("calendar.search.placeholder"), text: $model.searchQuery)
                .font(DPFont.light(size: 11, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
                .padding(.horizontal, 6)
                .frame(minWidth: 0, minHeight: 42)
                .submitLabel(.search)
                .onSubmit { performSearch() }
            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DPColor.accentHover)
                    .frame(width: 42, height: 42)
                    .background(DPColor.accentSoft)
            }
        }
        .frame(width: 82, height: 42)
        .background(DPColor.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
    }

    private func performSearch() {
        guard model.canSearchSchedules else { return }
        showsSearch = true
        if !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { await model.search() }
        }
    }

    private var dutyToolbar: some View {
        VStack(spacing: DPSpacing.extraSmall) {
            if model.isQuickDutyEditing { quickDutyBar }
            HStack(spacing: DPSpacing.small) {
                dutySummary
                    .frame(maxWidth: .infinity, alignment: .leading)
                toolbarActions
            }
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 0) {
            if model.isMyCalendar && !model.friends.isEmpty {
                Button { showsDutyComparison = true } label: {
                    Image(systemName: "person.2")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.compare"))
            } else if !model.isMyCalendar, model.me?.id != nil {
                Button { Task { await model.toggleMyDutyComparison() } } label: {
                    Image(systemName: model.comparedMemberIDs.isEmpty ? "person.2" : "person.2.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.compare.mine"))
            }
            if model.canEdit && !model.visibleDutyTypes.isEmpty {
                Button { model.setQuickDutyEditing(!model.isQuickDutyEditing) } label: {
                    Image(systemName: model.isQuickDutyEditing ? "xmark" : "pencil.line")
                        .foregroundStyle(model.isQuickDutyEditing ? DPColor.warning : DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text(model.isQuickDutyEditing ? "calendar.duty.quick.exit" : "calendar.duty.quick.start"))
            }
            Menu {
                if model.isMyCalendar {
                    Button(CalendarLocalization.text("calendar.dday.add"), systemImage: "calendar.badge.plus") { showsDDayEditor = true }
                    Button(CalendarLocalization.text("calendar.pattern"), systemImage: "repeat") { showsPattern = true }
                    Button(CalendarLocalization.text("calendar.todo.showTodo"), systemImage: model.showTodoItems ? "checkmark.circle.fill" : "circle") {
                        Task { await model.toggleTodoItems() }
                    }
                }
                if model.isMyCalendar && !model.visibleDutyTypes.isEmpty {
                    Button(CalendarLocalization.text("calendar.duty.batch"), systemImage: "square.grid.3x3") { showsBatchUpdate = true }
                }
                if model.isMyCalendar && model.team?.dutyBatchTemplate != nil {
                    Button(CalendarLocalization.text("calendar.duty.excel"), systemImage: "doc.badge.arrow.up") { importsDutyBatch = true }
                }
                Button(CalendarLocalization.text("calendar.today"), systemImage: "arrow.uturn.backward") { Task { await model.goToToday() } }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(CalendarLocalization.text("calendar.more"))
        }
        .foregroundStyle(DPColor.textSecondary)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
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
        let counts = Dictionary(grouping: model.days.compactMap(\.duty).filter { $0.month == model.month }, by: { $0.dutyType ?? CalendarLocalization.text("calendar.off") })
        return AnyView(ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.small) {
                ForEach(counts.keys.sorted(), id: \.self) { name in
                    HStack(spacing: DPSpacing.extraSmall) {
                        RoundedRectangle(cornerRadius: 2).fill(color(hex: counts[name]?.first?.dutyColor)).frame(width: 16, height: 16)
                        Text(name).foregroundStyle(DPColor.textSecondary)
                        Text("\(counts[name]?.count ?? 0)").bold().foregroundStyle(DPColor.textPrimary)
                    }
                    .font(DPTypography.caption)
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(["sun", "mon", "tue", "wed", "thu", "fri", "sat"], id: \.self) { weekday in
                    Text(CalendarLocalization.text("calendar.weekday.\(weekday)"))
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(weekday == "sun" ? DPColor.dangerHover : weekday == "sat" ? DPColor.accentHover : DPColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(DPColor.backgroundHover)
                        .overlay(alignment: .trailing) { Rectangle().fill(DPColor.borderSecondary).frame(width: 0.5) }
                        .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderSecondary).frame(height: 2) }
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
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }

    private var dDaySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DPSpacing.small) {
            ForEach(model.dDays, id: \.id) { item in
                DDayCard(item: item, editable: model.isMyCalendar, model: model)
            }
            if model.isMyCalendar {
                Button { showsDDayEditor = true } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(DPColor.backgroundTertiary)
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "plus").foregroundStyle(DPColor.textMuted))
                        Text("calendar.dday.add", tableName: "Calendar")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108)
                    .background(DPColor.backgroundCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .stroke(DPColor.borderSecondary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
            .background(DPColor.backgroundModal)
            .navigationTitle(CalendarLocalization.text("calendar.month.choose"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } } }
        }
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationDetents([.medium])
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
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
            .scrollContentBackground(.hidden)
            .background(DPColor.backgroundModal)
            .navigationTitle(CalendarLocalization.text("calendar.compare"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(CalendarLocalization.text("calendar.ok")) { dismiss() }
                }
            }
        }
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDayContent
    let weekday: Int
    let highlighted: Bool
    let pinnedDDay: DDayDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 1) {
                Text("\(day.cell.day)")
                    .font(DPFont.bold(size: 11, relativeTo: .caption))
                    .foregroundStyle(dayNumberColor)
                Spacer(minLength: 0)
                if let pinnedDDay {
                    Text(relativeLabel(pinnedDDay))
                        .font(DPFont.light(size: 8, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(secondaryForeground)
                }
            }
            if let holiday = day.holidays.first {
                Text(holiday.dateName)
                    .font(DPFont.light(size: 8, relativeTo: .caption2))
                    .lineLimit(1)
                    .foregroundStyle(holiday.isHoliday ? DPColor.dangerHover : secondaryForeground)
            }
            ForEach(Array(day.comparedDuties.prefix(3).enumerated()), id: \.offset) { _, item in
                comparedDutyChip(item)
            }
            ForEach(day.dDays.prefix(1), id: \.id) { item in
                statusBubble(item.title, image: "calendar.badge.checkmark", background: DPColor.successSoft, border: DPColor.successBorder, foreground: DPColor.successHover)
            }
            ForEach(day.schedules.prefix(CalendarVisualLogic.maximumSchedulesPerCell), id: \.id) { schedule in
                scheduleText(schedule)
            }
            if day.schedules.count > CalendarVisualLogic.maximumSchedulesPerCell {
                Text("+\(day.schedules.count - CalendarVisualLogic.maximumSchedulesPerCell)")
                    .font(DPFont.bold(size: 8, relativeTo: .caption2))
                    .foregroundStyle(secondaryForeground)
            }
            ForEach(day.todos.prefix(CalendarVisualLogic.maximumTodosPerCell), id: \.id) { todo in
                statusBubble(
                    todo.title,
                    image: "checkmark.square",
                    background: todo.status == .inProgress ? DPColor.warningSoft : DPColor.accentSoft,
                    border: todo.status == .inProgress ? DPColor.warningBorder : DPColor.accentBorder,
                    foreground: todo.status == .inProgress ? DPColor.warningHover : DPColor.accentHover
                )
            }
            if day.todos.count > CalendarVisualLogic.maximumTodosPerCell {
                Text("+\(day.todos.count - CalendarVisualLogic.maximumTodosPerCell)")
                    .font(DPFont.bold(size: 8, relativeTo: .caption2))
                    .foregroundStyle(secondaryForeground)
            }
            Spacer(minLength: 0)
        }
        .padding(2)
        .frame(maxWidth: .infinity, minHeight: CalendarVisualLogic.compactCellMinimumHeight, alignment: .topLeading)
        .background(cellBackground)
        .opacity(day.cell.isCurrentMonth ? 1 : 0.45)
        .overlay(alignment: .trailing) { Rectangle().fill(cellBorder).frame(width: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(cellBorder).frame(height: 0.5) }
        .overlay(Rectangle().stroke(focusBorder, lineWidth: highlighted || isToday ? 2 : 0))
        .contentShape(Rectangle())
        .accessibilityLabel(day.cell.date.rawValue)
    }

    private var cellBackground: Color {
        guard let components = CalendarVisualLogic.rgb(day.duty?.dutyColor) else {
            return day.cell.isCurrentMonth ? DPColor.backgroundCard : DPColor.backgroundSecondary
        }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }

    private var primaryForeground: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.textPrimary }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor) ? DPColor.textOnDark : DPColor.textOnLight
    }

    private var secondaryForeground: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.textMuted }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor) ? DPColor.textOnDarkMuted : DPColor.textMuted
    }

    private var dayNumberColor: Color {
        if weekday == 0 || !day.holidays.isEmpty { return DPColor.dangerHover }
        if weekday == 6 { return DPColor.accentHover }
        return primaryForeground
    }

    private var cellBorder: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.borderSecondary }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor)
            ? DPColor.textOnDark.opacity(0.30)
            : DPColor.textOnLight.opacity(0.15)
    }

    private var focusBorder: Color {
        if highlighted { return DPColor.accent }
        return isToday ? DPColor.danger : .clear
    }

    private var isToday: Bool {
        let today = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        return day.cell.year == today.year && day.cell.month == today.month && day.cell.day == today.day
    }

    private func scheduleText(_ schedule: ScheduleDTO) -> some View {
        Text(schedule.content)
            .font(DPFont.light(size: 8, relativeTo: .caption2))
            .foregroundStyle(primaryForeground)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 1)
            .overlay(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
                    .foregroundStyle(cellBorder)
                    .frame(height: 0.75)
            }
    }

    private func statusBubble(_ text: String, image: String, background: Color, border: Color, foreground: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: image).font(.system(size: 7, weight: .semibold))
            Text(text).lineLimit(1)
        }
        .font(DPFont.light(size: 8, relativeTo: .caption2))
        .foregroundStyle(foreground)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 0.5))
    }

    private func comparedDutyChip(_ item: ComparedDuty) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(DPColor.backgroundTertiary)
                .frame(width: 10, height: 10)
                .overlay(Text(item.name.prefix(1)).font(.system(size: 6, weight: .bold)).foregroundStyle(DPColor.textSecondary))
            Text(item.duty.dutyType ?? CalendarLocalization.text("calendar.off"))
                .lineLimit(1)
        }
        .font(DPFont.bold(size: 7, relativeTo: .caption2))
        .foregroundStyle(primaryForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .scrollContentBackground(.hidden)
            .background(DPColor.backgroundModal)
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
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
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
            .scrollContentBackground(.hidden)
            .background(DPColor.backgroundModal)
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
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
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
            .scrollContentBackground(.hidden)
            .background(DPColor.backgroundModal)
            .navigationTitle(CalendarLocalization.text("calendar.search"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(CalendarLocalization.text("calendar.close")) { dismiss() } } }
        }
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
    }
}

private struct DDayCard: View {
    let item: DDayDTO
    let editable: Bool
    @ObservedObject var model: CalendarViewModel
    @State private var edits = false
    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack(alignment: .top) {
                    Text(dDayLabel)
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(badgeForeground)
                        .padding(.horizontal, DPSpacing.small)
                        .padding(.vertical, DPSpacing.extraSmall)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: DPSpacing.extraSmall) {
                    if item.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DPColor.textMuted)
                    }
                    Text(item.title)
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                Label(item.date.rawValue, systemImage: "calendar.badge.checkmark")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(model.pinnedDDayID == item.id ? DPColor.warning : DPColor.borderPrimary, lineWidth: model.pinnedDDayID == item.id ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                Button { model.togglePinnedDDay(item) } label: {
                    Image(systemName: model.pinnedDDayID == item.id ? "star.fill" : "star")
                        .foregroundStyle(model.pinnedDDayID == item.id ? DPColor.warning : DPColor.textMuted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
        }
        .contentShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .onTapGesture { if editable { edits = true } }
        .shadow(color: .black.opacity(model.pinnedDDayID == item.id ? 0.12 : 0.05), radius: model.pinnedDDayID == item.id ? 4 : 1, y: 1)
        .sheet(isPresented: $edits) { DDayEditorView(model: model, existing: item) }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: item.calc <= 0
                ? [DPColor.backgroundSecondary, DPColor.backgroundTertiary]
                : [DPColor.backgroundCard, DPColor.backgroundSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var badgeBackground: Color {
        switch item.calc {
        case 0, 1: DPColor.danger
        case 2, 3: DPColor.warning
        case ..<0: DPColor.textMuted
        default: DPColor.backgroundTertiary
        }
    }

    private var badgeForeground: Color {
        item.calc > 3 ? DPColor.textPrimary : DPColor.textOnDark
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
        VStack(spacing: 0) {
            HStack {
                Text(CalendarLocalization.text(existing == nil ? "calendar.dday.add" : "calendar.dday.edit"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.extraSmall)
            .background(DPColor.backgroundTertiary)
            .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: DPSpacing.medium) {
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        HStack {
                            Text("calendar.dday.name", tableName: "Calendar")
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textSecondary)
                            Spacer()
                            Text("\(title.count)/30")
                                .font(DPTypography.caption)
                                .foregroundStyle(title.count > 30 ? DPColor.danger : DPColor.textMuted)
                        }
                        TextField(CalendarLocalization.text("calendar.dday.name"), text: $title)
                            .dpInputChrome(isInvalid: title.isEmpty || title.count > 30)
                    }
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text("calendar.dday.date", tableName: "Calendar")
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textSecondary)
                        DatePicker(CalendarLocalization.text("calendar.dday.date"), selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DPSpacing.compact)
                            .frame(minHeight: 44)
                            .background(DPColor.backgroundInput)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput))
                    }
                    HStack(spacing: DPSpacing.small) {
                        ForEach([-7, -1, 0, 1, 7], id: \.self) { offset in
                            Button(offset == 0 ? CalendarLocalization.text("calendar.today") : (offset > 0 ? "+\(offset)" : "\(offset)")) {
                                date = CalendarDateSupport.calendar.date(byAdding: .day, value: offset, to: offset == 0 ? Date() : date) ?? date
                            }
                            .font(DPTypography.caption)
                            .foregroundStyle(offset == 0 ? DPColor.accentHover : DPColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(offset == 0 ? DPColor.accentSoft : DPColor.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                        }
                    }
                    HStack {
                        Label(CalendarLocalization.text("calendar.dday.private"), systemImage: isPrivate ? "lock.fill" : "lock.open")
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                        Spacer()
                        Toggle(CalendarLocalization.text("calendar.dday.private"), isOn: $isPrivate)
                            .labelsHidden()
                    }
                    .padding(DPSpacing.compact)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

                    if existing != nil {
                        Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { confirmsDelete = true }
                            .font(DPTypography.label)
                            .frame(minHeight: 44)
                    }
                }
                .padding(DPSpacing.compact)
            }
            HStack(spacing: DPSpacing.small) {
                Button(CalendarLocalization.text("calendar.cancel")) { dismiss() }
                    .buttonStyle(DPOutlineButtonStyle())
                Button(CalendarLocalization.text("calendar.save")) {
                    Task { if await model.saveDDay(existing: existing, title: title, date: date, isPrivate: isPrivate) { dismiss() } }
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(title.isEmpty || title.count > 30)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundModal)
            .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
        }
        .background(DPColor.backgroundModal)
        .presentationDetents([.medium])
        .presentationCornerRadius(DPRadius.standard)
        .confirmationDialog(CalendarLocalization.text("calendar.delete.confirm"), isPresented: $confirmsDelete) {
            if let existing { Button(CalendarLocalization.text("calendar.delete"), role: .destructive) { Task { await model.deleteDDay(existing); dismiss() } } }
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
            .scrollContentBackground(.hidden)
            .background(DPColor.backgroundModal)
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
        .tint(DPColor.accent)
        .toolbarBackground(DPColor.backgroundTertiary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationCornerRadius(DPRadius.standard)
        .presentationBackground(DPColor.backgroundModal)
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
