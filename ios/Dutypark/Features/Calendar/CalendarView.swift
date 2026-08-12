import SwiftUI
import UniformTypeIdentifiers

enum DDayModalSelection: Identifiable, Equatable {
    case create
    case detail(DDayDTO)

    var id: String {
        switch self {
        case .create: "create"
        case .detail(let item): "detail-\(item.id)"
        }
    }
}

struct CalendarView: View {
    @StateObject private var model: CalendarViewModel
    @State private var showsSearch = false
    @State private var dDayModalSelection: DDayModalSelection?
    @State private var showsBatchUpdate = false
    @State private var showsMonthPicker = false
    @State private var showsDutyComparison = false
    @State private var importsDutyBatch = false
    @State private var showsTodoBoard = false
    @State private var todoTarget: TodoID?
    @State private var dayModalCanDismiss = true
    @State private var dDayModalCanDismiss = true

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
                onDismiss: {
                    model.selectedDay = nil
                    dayModalCanDismiss = true
                },
                closeOnBackdrop: false,
                canDismiss: dayModalCanDismiss
            ) { availableSize, dismiss in
                DayDetailView(
                    model: model,
                    initialDay: day,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { dayModalCanDismiss = $0 }
                ) {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showsSearch) {
            DPModalOverlay(onDismiss: { showsSearch = false }, closeOnBackdrop: false) { availableSize, dismiss in
                ScheduleSearchView(model: model, maximumHeight: availableSize.height, dismiss: dismiss)
            }
        }
        .fullScreenCover(item: $dDayModalSelection) { selection in
            DPModalOverlay(
                onDismiss: {
                    dDayModalSelection = nil
                    dDayModalCanDismiss = true
                },
                closeOnBackdrop: false,
                canDismiss: dDayModalCanDismiss
            ) { availableSize, dismiss in
                DDayModalView(
                    model: model,
                    selection: selection,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { dDayModalCanDismiss = $0 },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $showsMonthPicker) {
            DPModalOverlay(onDismiss: { showsMonthPicker = false }, closeOnBackdrop: false) { availableSize, dismiss in
                YearMonthPickerView(
                    model: model,
                    maximumHeight: availableSize.height,
                    dismiss: dismiss
                )
            }
        }
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
        Button { withoutPresentationAnimation { showsMonthPicker = true } } label: {
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
        withoutPresentationAnimation { showsSearch = true }
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
                        .font(DPFont.bold(size: CalendarTypography.weekday, relativeTo: .subheadline))
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
                DDayCard(item: item, model: model) {
                    withoutPresentationAnimation { dDayModalSelection = .detail(item) }
                }
            }
            if model.isMyCalendar {
                Button { withoutPresentationAnimation { dDayModalSelection = .create } } label: {
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

enum CalendarCompactModalLayout {
    static let maximumPanelHeightRatio: CGFloat = 0.9
    static let minimumBodyHeight: CGFloat = 1

    static func bodyHeight(
        contentHeight: CGFloat,
        maximumPanelHeight: CGFloat,
        fixedChromeHeight: CGFloat
    ) -> CGFloat {
        let availableHeight = max(minimumBodyHeight, maximumPanelHeight - fixedChromeHeight)
        return min(max(contentHeight, minimumBodyHeight), availableHeight)
    }
}

private struct YearMonthPickerView: View {
    @ObservedObject var model: CalendarViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var pickerYear: Int
    @State private var isSelecting = false

    init(model: CalendarViewModel, maximumHeight: CGFloat, dismiss: @escaping () -> Void) {
        self.model = model
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        _pickerYear = State(initialValue: model.year)
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
        ) {
            header
        } content: {
            pickerBody
        } footer: {
            footerActions
        }
        .opacity(isSelecting ? DPChrome.disabledOpacity : 1)
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text("calendar.month.choose"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: guardedDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSelecting)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
    }

    private var pickerBody: some View {
        VStack(spacing: DPSpacing.medium) {
            HStack(spacing: DPSpacing.small) {
                Button { pickerYear -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.format("calendar.month.format", pickerYear - 1, model.month))

                Spacer(minLength: 0)

                Text(String(pickerYear))
                    .font(DPTypography.sectionTitle)
                    .foregroundStyle(DPColor.textPrimary)

                Spacer(minLength: 0)

                Button { pickerYear += 1 } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.format("calendar.month.format", pickerYear + 1, model.month))
            }
            .foregroundStyle(DPColor.accent)
            .disabled(isSelecting)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DPSpacing.small), count: 4),
                spacing: DPSpacing.small
            ) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = pickerYear == model.year && month == model.month
                    Button {
                        select(month: month)
                    } label: {
                        Text(CalendarLocalization.format("calendar.month.short", month))
                            .font(DPTypography.label)
                            .foregroundStyle(isSelected ? DPColor.textOnDark : DPColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                            .background(isSelected ? DPColor.accent : DPColor.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            .overlay {
                                RoundedRectangle(cornerRadius: DPRadius.standard)
                                    .stroke(isSelected ? DPColor.accent : DPColor.borderPrimary)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelecting)
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private var footerActions: some View {
        HStack(spacing: DPSpacing.small) {
            Button(action: guardedDismiss) {
                Text(CalendarLocalization.text("calendar.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isSelecting)

            Button {
                selectCurrentMonth()
            } label: {
                HStack(spacing: DPSpacing.extraSmall) {
                    if isSelecting { ProgressView().controlSize(.small) }
                    Text(CalendarLocalization.text("calendar.month.current"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(isSelecting)
        }
        .padding(DPSpacing.compact)
    }

    private func guardedDismiss() {
        guard !isSelecting else { return }
        dismiss()
    }

    private func select(month: Int) {
        guard !isSelecting else { return }
        isSelecting = true
        Task {
            await model.selectYearMonth(year: pickerYear, month: month)
            dismiss()
        }
    }

    private func selectCurrentMonth() {
        guard !isSelecting else { return }
        isSelecting = true
        Task {
            await model.goToToday()
            dismiss()
        }
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
        DPModalPanel(
            maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
        ) {
            header
        } content: {
            friendGrid
        } footer: {
            footerActions
        }
    }

    private var header: some View {
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
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
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
        }
    }

    private var friendGrid: some View {
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

    private var footerActions: some View {
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

                Button(action: dismiss) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(isApplying)

                Button {
                    isApplying = true
                    Task {
                        await model.setFriendDutyComparisons(selection)
                        dismiss()
                    }
                } label: {
                    Group {
                        if isApplying {
                            ProgressView()
                        } else {
                            Text(CalendarLocalization.text("calendar.ok"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(isApplying)
            }
        }
        .padding(DPSpacing.medium)
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
                    .font(DPFont.bold(size: CalendarTypography.dayNumber, relativeTo: .caption))
                    .foregroundStyle(dayNumberColor)
                Spacer(minLength: 0)
                if let pinnedDDay, !hidesDetails {
                    Text(relativeLabel(pinnedDDay))
                        .font(DPFont.light(size: CalendarTypography.cellMicro, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(secondaryForeground)
                }
            }
            if !hidesDetails {
                if let holiday = day.holidays.first {
                    Text(holiday.dateName)
                        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
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
                        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
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
                        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
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
            .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
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
            Image(systemName: image).font(.system(size: CalendarTypography.cellMicro, weight: .semibold))
            Text(text).lineLimit(1)
        }
        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
        .foregroundStyle(foreground)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 0.5))
    }

    private func comparedDutyChip(_ item: ComparedDuty) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(DPColor.backgroundTertiary)
                .frame(width: 12, height: 12)
                .overlay(
                    Text(item.name.prefix(1))
                        .font(.system(size: CalendarTypography.cellMicro, weight: .bold))
                        .foregroundStyle(DPColor.textSecondary)
                )
            Text(item.duty.dutyType ?? CalendarLocalization.text("calendar.off"))
                .lineLimit(1)
        }
        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
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

enum CalendarScheduleDestructiveAction: Identifiable {
    case delete(ScheduleDTO)
    case untag(ScheduleDTO)

    var id: String {
        switch self {
        case .delete(let schedule): "delete-\(schedule.id)"
        case .untag(let schedule): "untag-\(schedule.id)"
        }
    }

    var titleKey: String {
        switch self {
        case .delete: "calendar.schedule.delete.confirm.title"
        case .untag: "calendar.schedule.untag.confirm.title"
        }
    }

    var actionKey: String {
        switch self {
        case .delete: "calendar.delete"
        case .untag: "calendar.schedule.untag"
        }
    }

    var message: String {
        switch self {
        case .delete(let schedule):
            CalendarLocalization.format("calendar.schedule.delete.confirm.message", schedule.content)
        case .untag(let schedule):
            CalendarLocalization.format("calendar.schedule.untag.confirm.message", schedule.content)
        }
    }
}

enum CalendarDestructiveActionPolicy {
    static func canBegin(isWorking: Bool) -> Bool { !isWorking }
}

enum CalendarModalDismissabilityPolicy {
    static func dayCanDismiss(
        isEditing: Bool,
        isPerformingDestructiveAction: Bool
    ) -> Bool {
        !isEditing && !isPerformingDestructiveAction
    }

    static func dDayCanDismiss(isWorking: Bool) -> Bool { !isWorking }
}

private struct CalendarDestructiveConfirmationModal: View {
    let action: CalendarScheduleDestructiveAction
    let isWorking: Bool
    let cancel: () -> Void
    let confirm: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(CalendarLocalization.text(action.titleKey))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DPSpacing.large)
                .frame(minHeight: 56)
                .background(DPColor.backgroundTertiary)

            Text(action.message)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.large)
                .frame(maxWidth: .infinity)

            HStack(spacing: DPSpacing.compact) {
                Button(action: cancel) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(isWorking)

                Button {
                    Task { await confirm() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView().tint(DPColor.textOnDark)
                        } else {
                            Text(CalendarLocalization.text(action.actionKey))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(isWorking)
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.bottom, DPSpacing.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DayDetailView: View {
    @ObservedObject var model: CalendarViewModel
    let initialDay: CalendarDayContent
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    let dismiss: () -> Void
    @State private var editorSchedule: ScheduleDTO?
    @State private var createsSchedule = false
    @State private var destructiveAction: CalendarScheduleDestructiveAction?
    @State private var isPerformingDestructiveAction = false

    private var day: CalendarDayContent {
        model.selectedDay ?? initialDay
    }

    private var showsEditor: Bool {
        createsSchedule || editorSchedule != nil
    }

    var body: some View {
        Group {
            if let destructiveAction {
                CalendarDestructiveConfirmationModal(
                    action: destructiveAction,
                    isWorking: isPerformingDestructiveAction,
                    cancel: { self.destructiveAction = nil },
                    confirm: performDestructiveAction
                )
            } else if showsEditor {
                VStack(spacing: 0) {
                    modalHeader

                    Divider().overlay(DPColor.borderPrimary)

                    ScheduleEditorView(
                        model: model,
                        day: day,
                        existing: editorSchedule,
                        onCancel: closeEditor,
                        onSaved: closeEditor,
                        onWorkingChange: { _ in reportDismissability() }
                    )
                    .id(editorSchedule?.id.uuidString ?? "new-\(day.id)")
                }
                .frame(height: maximumHeight, alignment: .top)
            } else {
                DPModalPanel(
                    maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
                ) {
                    modalHeader
                } content: {
                    scheduleList
                } footer: {
                    modalFooter
                }
            }
        }
        .onAppear(perform: reportDismissability)
        .onChange(of: showsEditor) { _, _ in reportDismissability() }
        .onChange(of: isPerformingDestructiveAction) { _, _ in reportDismissability() }
        .onDisappear { onDismissabilityChange(true) }
        .alert(
            CalendarLocalization.text("calendar.error.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
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
                    .font(DPFont.bold(size: CalendarTypography.detailTitle, relativeTo: .headline))
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
    }

    private var scheduleList: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
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
                Button(action: dismiss) {
                    Text(CalendarLocalization.text("calendar.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func scheduleCard(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(schedule.content)
                            .font(DPFont.light(size: CalendarTypography.detailTitle, relativeTo: .body))
                            .foregroundStyle(DPColor.textPrimary)
                        if schedule.totalDays > 1 {
                            Text("(\(schedule.daysFromStart)/\(schedule.totalDays))")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.accent)
                        }
                    }
                    if let time = scheduleTime(schedule) {
                        Text(time)
                            .font(DPFont.light(size: CalendarTypography.detailMetadata, relativeTo: .subheadline))
                            .foregroundStyle(DPColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if schedule.isTagged, model.isMyCalendar {
                    Button {
                        destructiveAction = .untag(schedule)
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
                        destructiveAction = .delete(schedule)
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
            .font(DPFont.light(size: CalendarTypography.detailMetadata, relativeTo: .subheadline))
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

    private func performDestructiveAction() async {
        guard let destructiveAction,
              CalendarDestructiveActionPolicy.canBegin(isWorking: isPerformingDestructiveAction)
        else { return }
        isPerformingDestructiveAction = true
        switch destructiveAction {
        case .delete(let schedule):
            let succeeded = await model.deleteSchedule(schedule)
            isPerformingDestructiveAction = false
            if succeeded { self.destructiveAction = nil }
        case .untag(let schedule):
            let succeeded = await model.untagSelf(schedule)
            isPerformingDestructiveAction = false
            if succeeded { self.destructiveAction = nil }
        }
    }

    private func reportDismissability() {
        onDismissabilityChange(
            CalendarModalDismissabilityPolicy.dayCanDismiss(
                isEditing: showsEditor,
                isPerformingDestructiveAction: isPerformingDestructiveAction
            )
        )
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
    let onWorkingChange: (Bool) -> Void
    @State private var content: String
    @State private var description: String
    @State private var visibility: Visibility
    @State private var start: Date
    @State private var end: Date
    @State private var tagIDs: Set<MemberID>
    @State private var isSaving = false
    @State private var isDiscarding = false
    @State private var pendingAIConsentPolicy: PolicyDTO?
    @StateObject private var aiConsent = AIScheduleParsingConsentStore.shared
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
        onSaved: @escaping () -> Void,
        onWorkingChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.day = day
        self.existing = existing
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.onWorkingChange = onWorkingChange
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
                        guard !interactionsDisabled else { return }
                        isDiscarding = true
                        let discarded = await attachmentModel.discard()
                        isDiscarding = false
                        if discarded { onCancel() }
                    }
                } label: {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(interactionsDisabled)

                Button {
                    save()
                } label: {
                    Text(CalendarLocalization.text("calendar.save"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DPColor.backgroundModal)
            .overlay(alignment: .top) {
                Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
            }
        }
        .onAppear { onWorkingChange(interactionsDisabled) }
        .onChange(of: interactionsDisabled) { _, isWorking in
            onWorkingChange(isWorking)
        }
        .onDisappear { onWorkingChange(false) }
        .alert(
            CalendarLocalization.text("calendar.aiConsent.prompt.title"),
            isPresented: Binding(
                get: { pendingAIConsentPolicy != nil },
                set: { if !$0 { pendingAIConsentPolicy = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.aiConsent.prompt.agree")) {
                guard let memberID = model.me?.id,
                      let version = pendingAIConsentPolicy?.version
                else {
                    pendingAIConsentPolicy = nil
                    saveWithoutConsentRequest()
                    return
                }
                pendingAIConsentPolicy = nil
                isSaving = true
                Task {
                    _ = await aiConsent.grant(for: memberID, policyVersion: version)
                    await performSave()
                }
            }
            Button(CalendarLocalization.text("calendar.aiConsent.prompt.decline"), role: .destructive) {
                let memberID = model.me?.id
                pendingAIConsentPolicy = nil
                isSaving = true
                Task {
                    if let memberID { _ = await aiConsent.revoke(for: memberID) }
                    await performSave()
                }
            }
            Button(CalendarLocalization.text("calendar.cancel"), role: .cancel) {}
        } message: {
            Text(CalendarLocalization.text("calendar.aiConsent.prompt.message"))
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
            guard let memberID = model.me?.id else {
                await performSave()
                return
            }
            let decision = await aiConsent.saveDecision(
                for: memberID,
                start: start,
                end: end
            )
            switch decision {
            case .saveWithoutPrompt:
                await performSave()
            case .requestConsent(let policy):
                isSaving = false
                pendingAIConsentPolicy = policy
            }
        }
    }

    private func saveWithoutConsentRequest() {
        isSaving = true
        Task { await performSave() }
    }

    private func performSave() async {
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

    private var saveDisabled: Bool {
        interactionsDisabled
            || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || content.count > 50
            || end < start
    }

    private var interactionsDisabled: Bool {
        ScheduleEditorInteractionPolicy.interactionsDisabled(
            isSaving: isSaving,
            isUploading: attachmentModel.isBusy,
            isDiscarding: isDiscarding
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
    static func interactionsDisabled(
        isSaving: Bool,
        isUploading: Bool,
        isDiscarding: Bool = false
    ) -> Bool {
        isSaving || isUploading || isDiscarding
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
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    private var trimmedQuery: String {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * 0.85
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            results
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Label(CalendarLocalization.text("calendar.search"), systemImage: "magnifyingglass")
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, DPSpacing.compact)
            .background(DPColor.backgroundTertiary)

            Divider().overlay(DPColor.borderPrimary)

            HStack(spacing: DPSpacing.small) {
                TextField(CalendarLocalization.text("calendar.search.placeholder"), text: $model.searchQuery)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .submitLabel(.search)
                    .onSubmit(performSearch)
                    .padding(.horizontal, DPSpacing.compact)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundInput)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput))

                Button(action: performSearch) {
                    Group {
                        if model.isSearching {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(trimmedQuery.isEmpty || model.isSearching)
                .accessibilityLabel(CalendarLocalization.text("calendar.search.short"))
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.medium)
            .padding(.bottom, DPSpacing.small)

            HStack {
                if trimmedQuery.isEmpty {
                    Text(CalendarLocalization.text("calendar.search.hint"))
                } else {
                    Text(CalendarLocalization.format("calendar.search.summary", trimmedQuery, model.searchResults.count))
                }
                Spacer(minLength: 0)
            }
            .font(DPTypography.caption)
            .foregroundStyle(DPColor.textMuted)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.bottom, DPSpacing.small)
        }
    }

    private var results: some View {
        LazyVStack(spacing: DPSpacing.small) {
            if model.searchResults.isEmpty {
                Text(CalendarLocalization.text(trimmedQuery.isEmpty ? "calendar.search.hint" : "calendar.search.empty"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 68)
            } else {
                ForEach(Array(model.searchResults.enumerated()), id: \.offset) { _, item in
                    Button {
                        Task {
                            await model.showSearchResult(item)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            Text(item.content)
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(2)
                            Label(
                                item.startDateTime.rawValue.replacingOccurrences(of: "T", with: " "),
                                systemImage: "calendar"
                            )
                            Text(item.author)
                        }
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .padding(.horizontal, DPSpacing.compact)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.canLoadMoreSearchResults {
                Button {
                    Task { await model.loadMoreSearchResults() }
                } label: {
                    HStack(spacing: DPSpacing.extraSmall) {
                        if model.isSearching { ProgressView().controlSize(.small) }
                        Text(CalendarLocalization.text("calendar.search.more"))
                    }
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(model.isSearching)
            }
        }
        .padding(DPSpacing.medium)
    }

    private func performSearch() {
        guard !trimmedQuery.isEmpty, !model.isSearching else { return }
        Task { await model.search() }
    }
}

enum CalendarDDayDetailPolicy {
    static func canManage(isMyCalendar: Bool) -> Bool { isMyCalendar }
}

private struct DDayModalView: View {
    private enum Route {
        case detail
        case edit
        case confirmDelete
    }

    @ObservedObject var model: CalendarViewModel
    let selection: DDayModalSelection
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    let dismiss: () -> Void
    @State private var route: Route
    @State private var isDeleting = false
    @State private var isChildWorking = false

    init(
        model: CalendarViewModel,
        selection: DDayModalSelection,
        maximumHeight: CGFloat,
        onDismissabilityChange: @escaping (Bool) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.maximumHeight = maximumHeight
        self.onDismissabilityChange = onDismissabilityChange
        self.dismiss = dismiss
        _route = State(initialValue: selection == .create ? .edit : .detail)
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch selection {
            case .create:
                DDayEditorView(
                    model: model,
                    existing: nil,
                    maximumHeight: maximumHeight,
                    dismiss: dismiss,
                    onWorkingChange: updateChildWorking
                )
            case .detail(let item):
                switch route {
                case .detail:
                    DDayDetailModal(
                        item: item,
                        isPinned: model.pinnedDDayID == item.id,
                        canManage: CalendarDDayDetailPolicy.canManage(isMyCalendar: model.isMyCalendar),
                        maximumHeight: maximumHeight,
                        dismiss: dismiss,
                        edit: { route = .edit },
                        delete: { route = .confirmDelete },
                        togglePin: { model.togglePinnedDDay(item) }
                    )
                case .edit:
                    DDayEditorView(
                        model: model,
                        existing: item,
                        maximumHeight: maximumHeight,
                        dismiss: dismiss,
                        onCancel: { route = .detail },
                        onDeleteRequest: { _ in route = .confirmDelete },
                        onWorkingChange: updateChildWorking
                    )
                case .confirmDelete:
                    DDayDeleteConfirmationModal(
                        item: item,
                        isWorking: isDeleting,
                        cancel: { route = .detail },
                        confirm: {
                            guard CalendarDestructiveActionPolicy.canBegin(isWorking: isDeleting) else { return }
                            isDeleting = true
                            let succeeded = await model.deleteDDay(item)
                            isDeleting = false
                            if succeeded {
                                onDismissabilityChange(true)
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
        .onAppear(perform: reportDismissability)
        .onChange(of: isDeleting) { _, _ in reportDismissability() }
        .onDisappear { onDismissabilityChange(true) }
        .alert(
            CalendarLocalization.text("calendar.error.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func updateChildWorking(_ isWorking: Bool) {
        isChildWorking = isWorking
        reportDismissability()
    }

    private func reportDismissability() {
        onDismissabilityChange(
            CalendarModalDismissabilityPolicy.dDayCanDismiss(
                isWorking: isDeleting || isChildWorking
            )
        )
    }
}

private struct DDayDetailModal: View {
    let item: DDayDTO
    let isPinned: Bool
    let canManage: Bool
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let togglePin: () -> Void

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * CalendarCompactModalLayout.maximumPanelHeightRatio
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            detailBody
        } footer: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DPSpacing.small) { footerActions }
                VStack(spacing: DPSpacing.small) { footerActions }
            }
            .padding(DPSpacing.compact)
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text("calendar.dday.detail.title"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
        .background(DPColor.backgroundTertiary)
    }

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            Text(dDayLabel)
                .font(DPFont.bold(size: 24, relativeTo: .title2))
                .foregroundStyle(DPColor.textOnDark)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.compact)
                .background(badgeBackground, in: Capsule())
                .frame(maxWidth: .infinity)

            detailField(
                label: CalendarLocalization.text("calendar.dday.name"),
                value: item.title,
                systemImage: item.isPrivate ? "lock.fill" : nil
            )
            detailField(
                label: CalendarLocalization.text("calendar.dday.date"),
                value: formattedDate,
                systemImage: "calendar.badge.checkmark"
            )

            if canManage {
                HStack(spacing: DPSpacing.small) {
                    Label(
                        CalendarLocalization.text(isPinned ? "calendar.dday.pin.enabled" : "calendar.dday.pin.disabled"),
                        systemImage: isPinned ? "star.fill" : "star"
                    )
                    .font(DPTypography.label)
                    .foregroundStyle(isPinned ? DPColor.warning : DPColor.textPrimary)
                    Spacer(minLength: 0)
                    Toggle(CalendarLocalization.text("calendar.dday.pin.action"), isOn: Binding(
                        get: { isPinned },
                        set: { _ in togglePin() }
                    ))
                    .labelsHidden()
                }
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
        .padding(DPSpacing.medium)
    }

    @ViewBuilder
    private var footerActions: some View {
        if canManage {
            Button(action: edit) {
                Label(CalendarLocalization.text("calendar.dday.edit.action"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())

            Button(action: delete) {
                Label(CalendarLocalization.text("calendar.delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPDestructiveButtonStyle())
        }

        Button(action: dismiss) {
            Text(CalendarLocalization.text("calendar.close"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DPOutlineButtonStyle())
    }

    private func detailField(label: String, value: String, systemImage: String?) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(label)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            if let systemImage {
                Label(value, systemImage: systemImage)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
            } else {
                Text(value)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: item.date) else { return item.date.rawValue }
        let formatter = DateFormatter()
        formatter.locale = CalendarLocalization.selectedLocale
        formatter.calendar = CalendarDateSupport.calendar
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMMdEEEE")
        return formatter.string(from: date)
    }

    private var dDayLabel: String {
        item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)"
    }

    private var badgeBackground: Color {
        switch item.calc {
        case 0, 1: DPColor.danger
        case 2, 3: DPColor.warning
        case ..<0: DPColor.textMuted
        default: DPColor.accent
        }
    }
}

private struct DDayDeleteConfirmationModal: View {
    let item: DDayDTO
    let isWorking: Bool
    let cancel: () -> Void
    let confirm: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(CalendarLocalization.text("calendar.dday.delete.confirm.title"))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DPSpacing.large)
                .frame(minHeight: 56)
                .background(DPColor.backgroundTertiary)

            Text(CalendarLocalization.format("calendar.dday.delete.confirm.message", item.title))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.large)

            HStack(spacing: DPSpacing.compact) {
                Button(action: cancel) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(isWorking)

                Button {
                    Task { await confirm() }
                } label: {
                    Group {
                        if isWorking { ProgressView().tint(DPColor.textOnDark) }
                        else { Text(CalendarLocalization.text("calendar.delete")) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(isWorking)
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.bottom, DPSpacing.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DDayCard: View {
    let item: DDayDTO
    @ObservedObject var model: CalendarViewModel
    let showDetail: () -> Void
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
                if model.isMyCalendar {
                    Button { model.togglePinnedDDay(item) } label: {
                        Image(systemName: model.pinnedDDayID == item.id ? "star.fill" : "star")
                            .foregroundStyle(model.pinnedDDayID == item.id ? DPColor.warning : DPColor.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .onTapGesture(perform: showDetail)
        .shadow(color: .black.opacity(model.pinnedDDayID == item.id ? 0.12 : 0.05), radius: model.pinnedDDayID == item.id ? 4 : 1, y: 1)
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
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let onCancel: (() -> Void)?
    let onDeleteRequest: ((DDayDTO) -> Void)?
    let onWorkingChange: (Bool) -> Void
    @State private var title: String
    @State private var date: Date
    @State private var isPrivate: Bool
    @State private var confirmsDelete = false
    @State private var isSaving = false

    init(
        model: CalendarViewModel,
        existing: DDayDTO?,
        maximumHeight: CGFloat,
        dismiss: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDeleteRequest: ((DDayDTO) -> Void)? = nil,
        onWorkingChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.existing = existing
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        self.onCancel = onCancel
        self.onDeleteRequest = onDeleteRequest
        self.onWorkingChange = onWorkingChange
        _title = State(initialValue: existing?.title ?? "")
        _date = State(initialValue: existing.flatMap { CalendarDateSupport.date(from: $0.date) } ?? Date())
        _isPrivate = State(initialValue: existing?.isPrivate ?? false)
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * CalendarCompactModalLayout.maximumPanelHeightRatio
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 30
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            editorBody
        } footer: {
            footer
        }
        .onAppear { onWorkingChange(isSaving) }
        .onChange(of: isSaving) { _, isWorking in onWorkingChange(isWorking) }
        .onDisappear { onWorkingChange(false) }
        .confirmationDialog(CalendarLocalization.text("calendar.delete.confirm"), isPresented: $confirmsDelete) {
            if let existing {
                Button(CalendarLocalization.text("calendar.delete"), role: .destructive) {
                    delete(existing)
                }
            }
            Button(CalendarLocalization.text("calendar.cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text(existing == nil ? "calendar.dday.add" : "calendar.dday.edit"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: guardedDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
    }

    private var editorBody: some View {
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
                    .dpInputChrome(isInvalid: !canSave)
                    .disabled(isSaving)
            }

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text("calendar.dday.date", tableName: "Calendar")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                DatePicker(
                    CalendarLocalization.text("calendar.dday.date"),
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput))
                .disabled(isSaving)
            }

            HStack(spacing: DPSpacing.small) {
                ForEach([-7, -1, 0, 1, 7], id: \.self) { offset in
                    Button(offset == 0 ? CalendarLocalization.text("calendar.today") : (offset > 0 ? "+\(offset)" : "\(offset)")) {
                        date = CalendarDateSupport.calendar.date(
                            byAdding: .day,
                            value: offset,
                            to: offset == 0 ? Date() : date
                        ) ?? date
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(offset == 0 ? DPColor.accentHover : DPColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .background(offset == 0 ? DPColor.accentSoft : DPColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                    .disabled(isSaving)
                }
            }

            HStack {
                Label(CalendarLocalization.text("calendar.dday.private"), systemImage: isPrivate ? "lock.fill" : "lock.open")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Toggle(CalendarLocalization.text("calendar.dday.private"), isOn: $isPrivate)
                    .labelsHidden()
                    .disabled(isSaving)
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

            if existing != nil {
                Button(CalendarLocalization.text("calendar.delete"), role: .destructive) {
                    if let existing, let onDeleteRequest {
                        onDeleteRequest(existing)
                    } else {
                        confirmsDelete = true
                    }
                }
                .font(DPTypography.label)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .disabled(isSaving)
            }
        }
        .padding(DPSpacing.medium)
        .opacity(isSaving ? DPChrome.disabledOpacity : 1)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button(action: guardedDismiss) {
                Text(CalendarLocalization.text("calendar.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isSaving)

            Button(action: save) {
                HStack(spacing: DPSpacing.extraSmall) {
                    if isSaving { ProgressView().controlSize(.small) }
                    Text(CalendarLocalization.text("calendar.save"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!canSave || isSaving)
        }
        .padding(DPSpacing.compact)
    }

    private func guardedDismiss() {
        guard !isSaving else { return }
        if let onCancel { onCancel() } else { dismiss() }
    }

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await model.saveDDay(
                existing: existing,
                title: title,
                date: date,
                isPrivate: isPrivate
            )
            isSaving = false
            onWorkingChange(false)
            if saved { dismiss() }
        }
    }

    private func delete(_ item: DDayDTO) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            let succeeded = await model.deleteDDay(item)
            isSaving = false
            onWorkingChange(false)
            if succeeded { dismiss() }
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
