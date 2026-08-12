import SwiftUI
import UniformTypeIdentifiers

struct CalendarView: View {
    @StateObject private var model: CalendarViewModel
    @State private var showsSearch = false
    @State private var showsDDayEditor = false
    @State private var showsBatchUpdate = false
    @State private var showsMonthPicker = false
    @State private var showsDutyComparison = false
    @State private var importsDutyBatch = false
    @State private var showsTodoBoard = false
    @State private var todoTarget: TodoID?

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
        .fullScreenCover(item: $model.selectedDay) { day in
            DPModalOverlay(
                onDismiss: { model.selectedDay = nil },
                closeOnBackdrop: false
            ) { availableSize, dismiss in
                DayDetailView(
                    model: model,
                    initialDay: day,
                    maximumHeight: availableSize.height
                ) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showsSearch) { ScheduleSearchView(model: model) }
        .sheet(isPresented: $showsDDayEditor) { DDayEditorView(model: model, existing: nil) }
        .sheet(isPresented: $showsMonthPicker) { YearMonthPickerView(model: model) }
        .fullScreenCover(isPresented: $showsDutyComparison) {
            DPModalOverlay(onDismiss: { showsDutyComparison = false }) { availableSize, dismiss in
                DutyComparisonView(model: model, maximumHeight: availableSize.height) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showsTodoBoard, onDismiss: { todoTarget = nil }) {
            NavigationStack {
                TodoView(
                    initialTodoID: todoTarget,
                    onTodoChanged: { _ = try? await model.loadMonth() },
                    onInitialTodoOpened: { todoTarget = nil }
                )
                .navigationTitle(CalendarLocalization.text("calendar.todo.manage"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(CalendarLocalization.text("calendar.close")) {
                            showsTodoBoard = false
                        }
                    }
                }
            }
        }
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
    }

    private var calendarContent: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.small) {
                calendarHeader
                if model.isMyCalendar, !model.isQuickDutyEditing {
                    dutyTodoRow
                }
                dutyToolbar
                calendarGrid
                if !model.isQuickDutyEditing {
                    dDaySection
                }
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.top, DPSpacing.extraSmall)
            .padding(.bottom, DPSpacing.large)
        }
        .refreshable { await model.load() }
    }

    private var calendarHeader: some View {
        HStack(spacing: 2) {
            memberIdentity
                .frame(maxWidth: .infinity, alignment: .leading)
            monthControls
                .fixedSize(horizontal: true, vertical: false)
            Group {
                if model.canSearchSchedules {
                    searchControl
                } else {
                    Color.clear
                        .frame(width: 116, height: 44)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
    }

    private var memberIdentity: some View {
        HStack(spacing: 6) {
            CalendarMemberAvatar(
                memberID: model.targetMemberID,
                name: model.targetName,
                hasProfilePhoto: model.targetHasProfilePhoto,
                profilePhotoVersion: model.targetProfilePhotoVersion,
                size: 32
            )
            Text(model.targetName)
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private var isViewingCurrentMonth: Bool {
        let current = CalendarDateSupport.calendar.dateComponents([.year, .month], from: Date())
        return current.year == model.year && current.month == model.month
    }

    private var monthLabel: some View {
        Button { showsMonthPicker = true } label: {
            Text(String(format: "%04d-%02d", model.year, model.month))
                .font(DPFont.bold(size: isViewingCurrentMonth ? 16 : 12, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.month.choose"))
    }

    private var todayShortcut: some View {
        Button { Task { await model.goToToday() } } label: {
            Text(CalendarLocalization.text("calendar.today"))
                .font(DPFont.bold(size: 10, relativeTo: .caption2))
                .foregroundStyle(DPColor.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.accentSoft)
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.today"))
    }

    private var monthCenterControls: some View {
        HStack(spacing: 0) {
            monthLabel
                .frame(width: isViewingCurrentMonth ? 88 : 44)
            if !isViewingCurrentMonth {
                todayShortcut
                    .frame(width: 44)
            }
        }
        .frame(width: 88)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
    }

    private var monthControls: some View {
        HStack(spacing: 0) {
            Button { Task { await model.changeMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            monthCenterControls
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
            TextField(
                "",
                text: $model.searchQuery,
                prompt: Text(CalendarLocalization.text("calendar.search.short"))
                    .foregroundStyle(DPColor.textMuted)
            )
                .font(DPFont.light(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
                .padding(.horizontal, 10)
                .frame(minWidth: 0, minHeight: 44)
                .submitLabel(.search)
                .onSubmit { performSearch() }
            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.accentHover)
                    .frame(width: 44, height: 44)
                    .background(DPColor.accentSoft)
            }
            .accessibilityLabel(CalendarLocalization.text("calendar.search"))
        }
        .frame(width: 116, height: 44)
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
            if model.isQuickDutyEditing {
                editModeNotice
                quickDutyBar
            } else {
                HStack(spacing: DPSpacing.small) {
                    dutySummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                    normalDutyActions
                }
            }
        }
    }

    private var normalDutyActions: some View {
        HStack(spacing: 0) {
            if model.isMyCalendar && !model.friends.isEmpty {
                Button {
                    withoutPresentationAnimation { showsDutyComparison = true }
                } label: {
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
                Button { model.setQuickDutyEditing(true) } label: {
                    Image(systemName: "pencil.line")
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.duty.quick.start"))
            }
            if model.isMyCalendar, model.team?.dutyBatchTemplate != nil {
                Button { importsDutyBatch = true } label: {
                    Image(systemName: "doc.badge.arrow.up")
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.duty.excel"))
            }
        }
        .foregroundStyle(DPColor.textSecondary)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
    }

    private var editModeNotice: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                Circle()
                    .fill(DPColor.backgroundPrimary)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DPColor.warning)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(CalendarLocalization.text("calendar.duty.quick.start"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textPrimary)
                    Text("calendar.duty.quick.description", tableName: "Calendar")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { model.setQuickDutyEditing(false) } label: {
                Label(CalendarLocalization.text("calendar.duty.quick.exit"), systemImage: "xmark")
                    .font(DPTypography.caption)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(DPColor.warning)
        }
        .padding(DPSpacing.small)
        .background(DPColor.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.warningBorder))
    }

    private var dutyTodoRow: some View {
        HStack(spacing: DPSpacing.small) {
            HStack(spacing: 0) {
                Button { openTodoBoard() } label: {
                    HStack(spacing: 3) {
                        Text(CalendarLocalization.text("calendar.todo.manage"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                }

                Button { openTodoBoard() } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.todo.add"))
            }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))

            Button { Task { await model.toggleTodoItems() } } label: {
                Image(systemName: model.showTodoItems ? "checkmark.square.fill" : "list.bullet")
                    .foregroundStyle(model.showTodoItems ? DPColor.accent : DPColor.textMuted)
                    .frame(width: 44, height: 44)
                    .background(model.showTodoItems ? DPColor.accentSoft : DPColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .accessibilityLabel(CalendarLocalization.text("calendar.todo.showTodo"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(calendarTodoItems, id: \.id) { todo in
                        Button { openTodo(todo.id) } label: {
                            Text(todo.isTagged ? "\(todo.owner) · \(todo.title)" : todo.title)
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 9)
                                .frame(maxWidth: 150, minHeight: 32)
                                .background(todo.status == .inProgress ? DPColor.warningSoft : DPColor.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DPRadius.compact)
                                        .stroke(todo.status == .inProgress ? DPColor.warningBorder : DPColor.accentBorder)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var calendarTodoItems: [TodoDTO] {
        (model.todoBoard?.inProgress ?? []) + (model.showTodoItems ? (model.todoBoard?.todo ?? []) : [])
    }

    private func openTodoBoard() {
        todoTarget = nil
        showsTodoBoard = true
    }

    private func openTodo(_ rawID: String) {
        guard let id = TodoID(uuidString: rawID) else { return }
        todoTarget = id
        showsTodoBoard = true
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
        CalendarFlowLayout(spacing: DPSpacing.small) {
            HStack(spacing: 0) {
                Button { model.moveQuickDutyFocus(by: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                Text(CalendarLocalization.format("calendar.duty.quick.day", model.quickDutyDay?.cell.day ?? 1))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.warning)
                    .frame(minWidth: 34)
                Button { model.moveQuickDutyFocus(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
            }
            .background(DPColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))

            quickDutyButton(
                id: nil,
                name: CalendarLocalization.text("calendar.off"),
                color: DPColor.backgroundCard,
                foreground: DPColor.textPrimary
            )

            ForEach(model.visibleDutyTypes, id: \.id) { type in
                quickDutyButton(
                    id: type.id,
                    name: type.name,
                    color: color(hex: type.color),
                    foreground: CalendarVisualLogic.usesLightForeground(on: type.color)
                        ? DPColor.textOnDark
                        : DPColor.textOnLight
                )
            }

            if model.isMyCalendar {
                Button { showsBatchUpdate = true } label: {
                    Text(CalendarLocalization.text("calendar.duty.batch"))
                        .font(DPTypography.caption)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(DPColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickDutyButton(
        id: DutyTypeID?,
        name: String,
        color: Color,
        foreground: Color
    ) -> some View {
        let selected = model.quickDutyDay?.duty?.dutyTypeId == id
        return Button { Task { await model.applyQuickDuty(dutyTypeID: id) } } label: {
            Text(name)
                .font(DPTypography.label)
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(selected ? DPColor.warning : DPColor.borderPrimary, lineWidth: selected ? 3 : 1)
                }
        }
        .buttonStyle(.plain)
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
                    CalendarDayCell(
                        day: day,
                        weekday: index % 7,
                        highlighted: model.highlightedDate == day.cell.date,
                        pinnedDDay: model.pinnedDDay,
                        hidesDetails: model.isQuickDutyEditing
                    )
                        .onTapGesture {
                            if model.isQuickDutyEditing { model.focusQuickDuty(on: day) }
                            else {
                                withoutPresentationAnimation { model.selectedDay = day }
                            }
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

private struct CalendarFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let availableWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: availableWidth, height: y + rowHeight), points)
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
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var selection: Set<MemberID>
    @State private var isApplying = false

    init(model: CalendarViewModel, maximumHeight: CGFloat, dismiss: @escaping () -> Void) {
        self.model = model
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        _selection = State(initialValue: model.comparedMemberIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(DPColor.accent)
                Text(CalendarLocalization.text("calendar.compare"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.textPrimary)
                .disabled(isApplying)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.extraSmall)
            .padding(.vertical, DPSpacing.extraSmall)
            .background(DPColor.backgroundTertiary)

            Text(CalendarLocalization.format("calendar.compare.description", 3))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.accentHover)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DPSpacing.medium)
                .padding(.vertical, DPSpacing.small)
                .background(DPColor.accentSoft)

            ScrollView {
                Group {
                    if model.friends.isEmpty {
                        Text(CalendarLocalization.text("calendar.compare.empty"))
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 88)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: DPSpacing.small), GridItem(.flexible())],
                            spacing: DPSpacing.small
                        ) {
                            ForEach(model.friends, id: \.id) { friend in
                                friendButton(friend)
                            }
                        }
                    }
                }
                .padding(DPSpacing.medium)
            }
            .frame(height: gridHeight)

            VStack(spacing: DPSpacing.small) {
                Text(CalendarLocalization.format("calendar.compare.count", selection.count, 3))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DPSpacing.small) {
                    Button {
                        selection.removeAll()
                    } label: {
                        Text(CalendarLocalization.text("calendar.compare.reset"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DPOutlineButtonStyle())
                    .disabled(selection.isEmpty || isApplying)

                    Button(CalendarLocalization.text("calendar.cancel"), action: dismiss)
                        .buttonStyle(DPSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(isApplying)

                    Button {
                        isApplying = true
                        Task {
                            await model.setFriendDutyComparisons(selection)
                            dismiss()
                        }
                    } label: {
                        if isApplying {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(CalendarLocalization.text("calendar.ok"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                    .disabled(isApplying)
                }
            }
            .padding(DPSpacing.medium)
            .background(DPColor.backgroundModal)
            .overlay(alignment: .top) {
                Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
            }
        }
        .background(DPColor.backgroundModal)
    }

    private var gridHeight: CGFloat {
        let rows = max(1, Int(ceil(Double(model.friends.count) / 2.0)))
        let intrinsic = CGFloat(rows * 66) + CGFloat(max(rows - 1, 0)) * DPSpacing.small + DPSpacing.medium * 2
        return min(intrinsic, max(maximumHeight - 250, 154))
    }

    private func friendButton(_ friend: FriendDTO) -> some View {
        let selected = selection.contains(friend.id)
        let disabled = !selected && selection.count >= 3
        return Button {
            if selected {
                selection.remove(friend.id)
            } else if selection.count < 3 {
                selection.insert(friend.id)
            }
        } label: {
            HStack(spacing: DPSpacing.small) {
                CalendarMemberAvatar(
                    memberID: friend.id,
                    name: friend.name,
                    hasProfilePhoto: friend.hasProfilePhoto,
                    profilePhotoVersion: friend.profilePhotoVersion,
                    size: 34
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(friend.name)
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    if let team = friend.team, !team.isEmpty {
                        Text(team)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? DPColor.accent : DPColor.textMuted)
            }
            .padding(.horizontal, DPSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: selected ? 2 : 1)
            }
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled || isApplying)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CalendarMemberAvatar: View {
    let memberID: MemberID?
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let size: CGFloat

    var body: some View {
        Group {
            if hasProfilePhoto, let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView().controlSize(.small).tint(DPColor.textMuted)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(DPColor.backgroundTertiary)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .overlay {
                Text(name.prefix(1).uppercased())
                    .font(DPFont.bold(size: max(11, size * 0.38), relativeTo: .caption))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    private var photoURL: URL? {
        guard let memberID else { return nil }
        var components = URLComponents(
            url: AppConfiguration.apiBaseURL.appending(path: "members/\(memberID)/profile-photo"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: String(profilePhotoVersion))
        ]
        return components?.url
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDayContent
    let weekday: Int
    let highlighted: Bool
    let pinnedDDay: DDayDTO?
    let hidesDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 1) {
                Text("\(day.cell.day)")
                    .font(DPFont.bold(size: 11, relativeTo: .caption))
                    .foregroundStyle(dayNumberColor)
                Spacer(minLength: 0)
                if let pinnedDDay, !hidesDetails {
                    Text(relativeLabel(pinnedDDay))
                        .font(DPFont.light(size: 8, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(secondaryForeground)
                }
            }
            if !hidesDetails {
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
        if weekday == 0 || (!hidesDetails && !day.holidays.isEmpty) { return DPColor.dangerHover }
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
    let initialDay: CalendarDayContent
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var editorSchedule: ScheduleDTO?
    @State private var createsSchedule = false

    private var day: CalendarDayContent {
        model.selectedDay ?? initialDay
    }

    private var showsEditor: Bool {
        createsSchedule || editorSchedule != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            modalHeader

            if showsEditor {
                ScheduleEditorView(
                    model: model,
                    day: day,
                    existing: editorSchedule,
                    onCancel: closeEditor,
                    onSaved: closeEditor
                )
                .id(editorSchedule?.id.uuidString ?? "new-\(day.id)")
            } else {
                scheduleList
                modalFooter
            }
        }
        .frame(height: showsEditor ? maximumHeight : nil, alignment: .top)
        .fixedSize(horizontal: false, vertical: !showsEditor)
        .background(DPColor.backgroundModal)
    }

    private var modalHeader: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                if createsSchedule {
                    modeBadge("calendar.schedule.add", color: DPColor.success)
                } else if editorSchedule != nil {
                    modeBadge("calendar.schedule.edit", color: DPColor.accent)
                }

                Text(formattedDate)
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    if !showsEditor { dismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.textPrimary)
                .opacity(showsEditor ? 0.35 : 1)
                .disabled(showsEditor)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }

            if model.canEdit, !showsEditor, !model.visibleDutyTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        dutyButton(id: nil, name: CalendarLocalization.text("calendar.off"), color: DPColor.backgroundCard)
                        ForEach(model.visibleDutyTypes, id: \.id) { type in
                            dutyButton(id: type.id, name: type.name, color: calendarColor(type.color))
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else if let duty = day.duty, !model.canEdit, !showsEditor {
                Text(duty.dutyType ?? CalendarLocalization.text("calendar.off"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textOnDark)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(calendarColor(duty.dutyColor))
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, DPSpacing.extraSmall)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
        }
    }

    private var scheduleList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DPSpacing.compact) {
                if day.schedules.isEmpty {
                    Text("calendar.schedule.empty", tableName: "Calendar")
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    ForEach(day.schedules, id: \.id) { schedule in
                        scheduleCard(schedule)
                    }
                }

            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: scheduleListHeight)
    }

    private var modalFooter: some View {
        HStack {
            if model.canEdit {
                Button {
                    createsSchedule = true
                } label: {
                    Label(CalendarLocalization.text("calendar.schedule.add"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSuccessButtonStyle())
            } else {
                Button(CalendarLocalization.text("calendar.close"), action: dismiss)
                    .buttonStyle(DPOutlineButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DPColor.backgroundModal)
        .overlay(alignment: .top) {
            Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
        }
    }

    private func scheduleCard(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(schedule.content)
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textPrimary)
                        if schedule.totalDays > 1 {
                            Text("(\(schedule.daysFromStart)/\(schedule.totalDays))")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.accent)
                        }
                    }
                    if let time = scheduleTime(schedule) {
                        Text(time)
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if schedule.isTagged, model.isMyCalendar {
                    Button {
                        Task { await model.untagSelf(schedule) }
                    } label: {
                        Label(CalendarLocalization.text("calendar.schedule.untag"), systemImage: "xmark")
                            .font(DPTypography.caption)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.warning)
                } else if model.canEdit {
                    Button {
                        editorSchedule = schedule
                    } label: {
                        Image(systemName: "pencil")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.accent)

                    Button {
                        Task { await model.deleteSchedule(schedule) }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.danger)
                }
            }

            scheduleMetadata(schedule)

            if !schedule.description.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                Text(schedule.description)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                    .textSelection(.enabled)
            }

            if !schedule.attachments.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                ScheduleAttachmentGallery(
                    schedule: schedule,
                    canEdit: model.canEdit && !schedule.isTagged
                )
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

    @ViewBuilder
    private func scheduleMetadata(_ schedule: ScheduleDTO) -> some View {
        if schedule.isTagged || !schedule.tags.isEmpty || schedule.visibility != nil {
            HStack(spacing: DPSpacing.small) {
                if schedule.isTagged {
                    Label(schedule.owner, systemImage: "person.crop.circle.badge.checkmark")
                }
                if !schedule.tags.isEmpty {
                    Label(schedule.tags.map(\.name).joined(separator: ", "), systemImage: "tag")
                }
                if let visibility = schedule.visibility, model.isMyCalendar {
                    Label(
                        CalendarLocalization.text("calendar.visibility.\(visibilityKey(visibility))"),
                        systemImage: "eye"
                    )
                }
            }
            .font(DPTypography.caption)
            .foregroundStyle(DPColor.textMuted)
            .lineLimit(1)
        }
    }

    private func dutyButton(id: DutyTypeID?, name: String, color: Color) -> some View {
        let selected = day.duty?.dutyTypeId == id
        return Button {
            Task { await model.updateDuty(day: day, dutyTypeID: id) }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3).stroke(DPColor.borderSecondary)
                    }
                Text(name)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(selected ? color.opacity(0.20) : DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.compact)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func modeBadge(_ key: String, color: Color) -> some View {
        Text(CalendarLocalization.text(key))
            .font(DPTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
    }

    private func closeEditor() {
        createsSchedule = false
        editorSchedule = nil
    }

    private var scheduleListHeight: CGFloat {
        guard !day.schedules.isEmpty else { return 76 }
        let estimatedRows = day.schedules.reduce(CGFloat.zero) { total, schedule in
            let descriptionHeight: CGFloat = schedule.description.isEmpty ? 0 : 48
            let attachmentHeight: CGFloat = schedule.attachments.isEmpty ? 0 : 112
            return total + 88 + descriptionHeight + attachmentHeight
        }
        return min(max(estimatedRows + 20, 124), 430)
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: day.cell.date) else {
            return day.cell.date.rawValue
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = CalendarLocalization.selectedLocale
        dateFormatter.calendar = CalendarDateSupport.calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMMd")
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = CalendarLocalization.selectedLocale
        weekdayFormatter.calendar = CalendarDateSupport.calendar
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")
        return "\(dateFormatter.string(from: date)) (\(weekdayFormatter.string(from: date)))"
    }

    private func scheduleTime(_ schedule: ScheduleDTO) -> String? {
        let start = String(schedule.startDateTime.rawValue.suffix(5))
        let end = String(schedule.endDateTime.rawValue.suffix(5))
        if start == "00:00", end == "00:00" { return nil }
        if start == end || end == "00:00" { return "(\(start))" }
        return "(\(start)~\(end))"
    }

    private func visibilityKey(_ visibility: Visibility) -> String {
        switch visibility {
        case .publicAccess: "public"
        case .friends: "friends"
        case .family: "family"
        case .privateAccess, .unknown: "private"
        }
    }

    private func calendarColor(_ hex: String?) -> Color {
        guard let hex else { return DPColor.backgroundCard }
        let value = UInt64(
            hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted),
            radix: 16
        ) ?? 0x6B7280
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

private struct ScheduleEditorView: View {
    @ObservedObject var model: CalendarViewModel
    let day: CalendarDayContent
    let existing: ScheduleDTO?
    let onCancel: () -> Void
    let onSaved: () -> Void
    @State private var content: String
    @State private var description: String
    @State private var visibility: Visibility
    @State private var start: Date
    @State private var end: Date
    @State private var tagIDs: Set<MemberID>
    @State private var isSaving = false
    @StateObject private var attachmentModel: AttachmentPickerModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case details
    }

    init(
        model: CalendarViewModel,
        day: CalendarDayContent,
        existing: ScheduleDTO?,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.model = model
        self.day = day
        self.existing = existing
        self.onCancel = onCancel
        self.onSaved = onSaved
        let base = CalendarDateSupport.date(from: day.cell.date) ?? Date()
        _content = State(initialValue: existing?.content ?? "")
        _description = State(initialValue: existing?.description ?? "")
        _visibility = State(initialValue: existing?.visibility ?? .family)
        _start = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.startDateTime) } ?? base)
        _end = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.endDateTime) } ?? base)
        _tagIDs = State(initialValue: Set(existing?.tags.compactMap(\.id) ?? []))
        _attachmentModel = StateObject(wrappedValue: AttachmentPickerModel(
            contextType: .schedule,
            targetContextId: existing?.id.uuidString,
            existingAttachments: existing?.attachments ?? []
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DPSpacing.small) {
                    formRow("calendar.schedule.content") {
                        ZStack(alignment: .trailing) {
                            TextField(CalendarLocalization.text("calendar.schedule.content.placeholder"), text: $content)
                                .textInputAutocapitalization(.sentences)
                                .font(DPFont.light(size: 15, relativeTo: .body))
                                .focused($focusedField, equals: .title)
                                .padding(.trailing, 54)
                                .dpInputChrome(isInvalid: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.count > 50)
                            Text("\(content.count)/50")
                                .font(DPTypography.caption)
                                .foregroundStyle(content.count > 50 ? DPColor.danger : DPColor.textMuted)
                                .padding(.trailing, DPSpacing.small)
                        }
                    }

                    formRow(existing == nil ? "calendar.schedule.startTime" : "calendar.schedule.start") {
                        DatePicker(
                            CalendarLocalization.text("calendar.schedule.start"),
                            selection: $start,
                            displayedComponents: existing == nil ? [.hourAndMinute] : [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .environment(\.locale, CalendarLocalization.selectedLocale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    formRow("calendar.schedule.end") {
                        DatePicker(
                            CalendarLocalization.text("calendar.schedule.end"),
                            selection: $end,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .environment(\.locale, CalendarLocalization.selectedLocale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    formRow("calendar.schedule.description", alignment: .top) {
                        TextField(
                            CalendarLocalization.text("calendar.schedule.description.placeholder"),
                            text: $description,
                            axis: .vertical
                        )
                        .font(DPFont.light(size: 15, relativeTo: .body))
                        .focused($focusedField, equals: .details)
                        .lineLimit(2...4)
                        .dpInputChrome()
                    }

                    formRow("calendar.schedule.visibility", alignment: .top) {
                        HStack(spacing: DPSpacing.extraSmall) {
                            visibilityButton(.publicAccess, icon: "globe")
                            visibilityButton(.friends, icon: "person.2")
                            visibilityButton(.family, icon: "heart")
                            visibilityButton(.privateAccess, icon: "lock")
                        }
                    }

                    formRow("calendar.schedule.attachments", alignment: .top) {
                        AttachmentPicker(model: attachmentModel)
                    }

                    if model.isMyCalendar, !model.friends.isEmpty {
                        formRow("calendar.schedule.tags", alignment: .top) {
                            CalendarFriendTagSelector(
                                friends: model.friends,
                                selectedSummaries: existing?.tags ?? [],
                                selection: $tagIDs,
                                disabled: interactionsDisabled
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)

            HStack(spacing: DPSpacing.small) {
                Button {
                    Task {
                        if await attachmentModel.discard() { onCancel() }
                    }
                } label: {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(interactionsDisabled)

                Button {
                    save()
                } label: {
                    Text(CalendarLocalization.text("calendar.save"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DPColor.backgroundModal)
            .overlay(alignment: .top) {
                Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
            }
        }
    }

    private func formRow<Content: View>(
        _ key: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: DPSpacing.small) {
            Text(CalendarLocalization.text(key))
                .font(DPFont.light(size: 13, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: 64, alignment: .leading)
                .padding(.top, alignment == .top ? 10 : 0)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func visibilityButton(_ option: Visibility, icon: String) -> some View {
        let selected = visibility == option
        return Button {
            visibility = option
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DPColor.accent)
                            .offset(x: 9, y: -8)
                    }
                }
                    .font(.system(size: 15, weight: .semibold))
                Text(CalendarLocalization.text("calendar.visibility.\(visibilityKey(option))"))
                    .font(DPFont.light(size: 11, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? DPColor.accent : DPColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func save() {
        isSaving = true
        Task {
            guard let attachments = await attachmentModel.resultForSave() else {
                isSaving = false
                return
            }
            let saved = await model.saveSchedule(
                existing: existing,
                content: content,
                description: description,
                visibility: visibility,
                start: start,
                end: end,
                tagFriendIDs: Array(tagIDs),
                attachmentSessionID: attachments.attachmentSessionId,
                orderedAttachmentIDs: attachments.orderedAttachmentIds
            )
            isSaving = false
            if saved { onSaved() }
        }
    }

    private var saveDisabled: Bool {
        interactionsDisabled
            || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || content.count > 50
            || end < start
    }

    private var interactionsDisabled: Bool {
        ScheduleEditorInteractionPolicy.interactionsDisabled(
            isSaving: isSaving,
            isUploading: attachmentModel.isBusy
        )
    }

    private func visibilityKey(_ value: Visibility) -> String {
        switch value {
        case .publicAccess: "public"
        case .friends: "friends"
        case .family: "family"
        case .privateAccess, .unknown: "private"
        }
    }
}

private struct CalendarFriendTagSelector: View {
    let friends: [FriendDTO]
    let selectedSummaries: [MemberDTO]
    @Binding var selection: Set<MemberID>
    let disabled: Bool
    @State private var isExpanded: Bool
    @State private var query = ""
    @State private var showsSelectedOnly = false

    init(
        friends: [FriendDTO],
        selectedSummaries: [MemberDTO],
        selection: Binding<Set<MemberID>>,
        disabled: Bool
    ) {
        self.friends = friends
        self.selectedSummaries = selectedSummaries
        _selection = selection
        self.disabled = disabled
        _isExpanded = State(initialValue: !selection.wrappedValue.isEmpty)
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedSelector
            } else {
                Button {
                    isExpanded = true
                } label: {
                    HStack(spacing: DPSpacing.compact) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DPColor.accent)
                            .frame(width: 40, height: 40)
                            .background(DPColor.backgroundTertiary)
                            .clipShape(Circle())
                        Text(CalendarLocalization.text("calendar.schedule.tags"))
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DPSpacing.compact)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large)
                        .stroke(DPColor.borderPrimary)
                }
                .disabled(disabled)
            }
        }
    }

    private var expandedSelector: some View {
        VStack(spacing: DPSpacing.small) {
            HStack(spacing: 6) {
                HStack(spacing: DPSpacing.small) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DPColor.textMuted)
                    TextField(CalendarLocalization.text("calendar.schedule.tags.search"), text: $query)
                        .font(DPTypography.label)
                        .textInputAutocapitalization(.never)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DPColor.textMuted)
                    }
                }
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: 44)
                .background(DPColor.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large)
                        .stroke(DPColor.borderInput)
                }

                if !selection.isEmpty {
                    Button {
                        showsSelectedOnly.toggle()
                    } label: {
                        Text(CalendarLocalization.format("calendar.schedule.tags.selected", selection.count))
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .foregroundStyle(showsSelectedOnly ? DPColor.textOnDark : DPColor.textPrimary)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 44)
                            .background(showsSelectedOnly ? DPColor.accent : DPColor.accentSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(CalendarLocalization.text("calendar.schedule.tags.selectedOnly"))

                    Button {
                        selection.removeAll()
                        showsSelectedOnly = false
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.textSecondary)
                    .accessibilityLabel(CalendarLocalization.text("calendar.schedule.tags.clear"))
                }
            }

            if visibleItems.isEmpty {
                Text(CalendarLocalization.text("calendar.schedule.tags.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)],
                        spacing: 1
                    ) {
                        ForEach(visibleItems) { item in
                            friendButton(item)
                        }
                    }
                }
                .frame(maxHeight: 146)
                .background(DPColor.borderPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            }
        }
        .padding(10)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary)
        }
    }

    private func friendButton(_ item: Item) -> some View {
        let selected = selection.contains(item.id)
        return Button {
            if selected { selection.remove(item.id) } else { selection.insert(item.id) }
        } label: {
            HStack(spacing: DPSpacing.small) {
                avatar(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(DPFont.light(size: 13, relativeTo: .subheadline))
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    if let team = item.team {
                        Text(team)
                            .font(DPFont.light(size: 11, relativeTo: .caption))
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DPColor.accent)
                }
            }
            .padding(.horizontal, DPSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? DPColor.accentSoftHover : DPColor.backgroundPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    @ViewBuilder
    private func avatar(_ item: Item) -> some View {
        if item.hasProfilePhoto {
            AsyncImage(url: profileURL(item)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarFallback(item)
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        } else {
            avatarFallback(item)
        }
    }

    private func avatarFallback(_ item: Item) -> some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: 24, height: 24)
            .overlay {
                Text(String(item.name.prefix(1)))
                    .font(DPFont.bold(size: 10, relativeTo: .caption2))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    private var visibleItems: [Item] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
        return allItems.filter { item in
            if showsSelectedOnly { return selection.contains(item.id) }
            guard !normalized.isEmpty else { return true }
            return "\(item.name) \(item.team ?? "")".localizedLowercase.contains(normalized)
        }
    }

    private var allItems: [Item] {
        let friendItems = friends.map { Item(friend: $0) }
        let existingIDs = Set(friendItems.map(\.id))
        let unavailable = selectedSummaries.compactMap { member -> Item? in
            guard let id = member.id, selection.contains(id), !existingIDs.contains(id) else { return nil }
            return Item(member: member)
        }
        return (friendItems + unavailable).sorted { lhs, rhs in
            if lhs.pinOrder != rhs.pinOrder {
                if lhs.pinOrder == nil { return false }
                if rhs.pinOrder == nil { return true }
                return lhs.pinOrder! < rhs.pinOrder!
            }
            if lhs.isFamily != rhs.isFamily { return lhs.isFamily }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    private func profileURL(_ item: Item) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(item.id)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(item.profilePhotoVersion))
            ])
    }

    private struct Item: Identifiable {
        let id: MemberID
        let name: String
        let team: String?
        let hasProfilePhoto: Bool
        let profilePhotoVersion: Int64
        let isFamily: Bool
        let pinOrder: Int64?

        init(friend: FriendDTO) {
            id = friend.id
            name = friend.name
            team = friend.team
            hasProfilePhoto = friend.hasProfilePhoto
            profilePhotoVersion = friend.profilePhotoVersion
            isFamily = friend.isFamily
            pinOrder = friend.pinOrder
        }

        init(member: MemberDTO) {
            id = member.id ?? -1
            name = member.name
            team = member.team
            hasProfilePhoto = member.hasProfilePhoto
            profilePhotoVersion = member.profilePhotoVersion
            isFamily = false
            pinOrder = nil
        }
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
