import Foundation
import SwiftUI

/// What the field commits, and how.
///
/// `range` is the hotel-style check-in/check-out picker: it is anchored at a day the user
/// cannot move, a tap only *stages* an end, and nothing reaches the binding until the footer's
/// confirm is pressed. `single` commits the day it was tapped on and closes.
nonisolated enum DPDateFieldMode: Equatable, Sendable {
    case single
    case range(anchor: DateOnly)
}

/// The answer to a tap on a day cell. Committing and staging are deliberately different
/// outcomes: the range picker must not be able to write a value behind the confirm step.
nonisolated enum DPDateFieldTap: Equatable, Sendable {
    case ignored
    case staged(DateOnly)
    case committed(DateOnly)
}

/// Base metrics for the field, kept in a `nonisolated enum` so the numbers can be asserted
/// without a snapshot. The view wraps each of them in `@ScaledMetric` so they follow the text
/// size; the collapsed row is the exception — its height comes from the caller, which owns the
/// row budget the field has to fit inside.
///
/// The tokens this table mirrors (`DPRadius`, `DPSpacing`, `DPSize`) are main-actor isolated in
/// this target, so the values are inlined here and named in the comments.
nonisolated enum DPDateFieldLayout {
    /// A 375-point phone gives seven columns about 43 points each once the modal, the form and
    /// the calendar's own padding have taken theirs, so a 36-point row keeps the cell close to
    /// square while six weeks still fit an iPhone 13 mini.
    static let dayCellHeight: CGFloat = 36
    static let weekdayHeaderHeight: CGFloat = 22
    static let headerControlSize: CGFloat = 32
    /// `DPSize.minimumTouchTarget`: the footer draws the house button styles.
    static let footerActionHeight: CGFloat = 44
    static let footerSummaryHeight: CGFloat = 34
    /// The duration chip: a 12-point line plus the padding that makes it a capsule.
    static let footerDurationHeight: CGFloat = 21
    /// `DPRadius.standard`, the radius every other input in the app rounds to.
    static let dayCornerRadius: CGFloat = 8
    /// `DPSpacing.small`.
    static let contentSpacing: CGFloat = 8

    static let fieldFontSize: CGFloat = 14
    static let monthTitleFontSize: CGFloat = 15
    static let weekdayFontSize: CGFloat = 11
    static let dayFontSize: CGFloat = 13
    static let todayFontSize: CGFloat = 12
    static let summaryLabelFontSize: CGFloat = 11
    static let summaryValueFontSize: CGFloat = 13
    static let durationFontSize: CGFloat = 12
    static let fieldIconSize: CGFloat = 14
    static let navigationIconSize: CGFloat = 13

    static func monthGridHeight(
        dayHeight: CGFloat = dayCellHeight,
        headerHeight: CGFloat = weekdayHeaderHeight
    ) -> CGFloat {
        headerHeight + CGFloat(DatePickerGridLogic.weeksPerGrid) * dayHeight
    }

    /// The width the expanded calendar actually covers. It is deliberately not the width of the
    /// column the collapsed row sits in: a form that hangs a label column off its leading edge
    /// narrows that column enough to squeeze the grid, and seven columns feel the squeeze seven
    /// times over. The calendar bleeds back across the label instead and takes the whole row.
    static func expandedWidth(containerWidth: CGFloat, leadingBleed: CGFloat) -> CGFloat {
        containerWidth + max(0, leadingBleed)
    }

    /// The width of one day cell. The calendar's own padding comes off first and the rest
    /// divides by seven; the cells carry no spacing between them, because the span has to close
    /// up into one bar, so this is both the cell's width and the grid's pitch.
    static func dayCellWidth(
        expandedWidth: CGFloat,
        padding: CGFloat = contentSpacing
    ) -> CGFloat {
        max(0, expandedWidth - padding * 2) / CGFloat(DatePickerGridLogic.daysPerWeek)
    }

    /// Natural height of the expanded calendar at the default text size, so the fit on the
    /// smallest supported phone is a number a test can check rather than a hope.
    static func expandedHeight(
        includesFooter: Bool,
        dayHeight: CGFloat = dayCellHeight,
        headerHeight: CGFloat = weekdayHeaderHeight
    ) -> CGFloat {
        var height = contentSpacing * 2
            + headerControlSize
            + contentSpacing
            + monthGridHeight(dayHeight: dayHeight, headerHeight: headerHeight)
        guard includesFooter else { return height }
        height += contentSpacing * 2
            + footerSummaryHeight
            + footerDurationHeight
            + footerActionHeight
            + contentSpacing
        return height
    }
}

/// Field-level policy layered on `DatePickerGridLogic`, mirrored from
/// `frontend/src/components/common/DatePickerField.vue` so the two clients answer identically.
///
/// Everything the view would otherwise decide inline lives here: which mode is really in force,
/// where the grid's floor is, what a tap means, which months can still be reached, and how one
/// day cell is painted inside the span.
nonisolated enum DPDateFieldPolicy {
    /// The anchor a range is measured from, or `nil` when there is no usable one. This is the
    /// mode switch as well: an anchor that is not a real day degrades the field to `single`
    /// rather than leaving a range grid with no floor.
    static func anchor(of mode: DPDateFieldMode) -> DateOnly? {
        guard case let .range(anchor) = mode, DatePickerGridLogic.isValidDay(anchor) else { return nil }
        return anchor
    }

    /// The one lower bound the whole field obeys, so disabling, month paging and the today
    /// control all stop in the same place.
    static func lowerBound(mode: DPDateFieldMode, minimum: DateOnly?) -> DateOnly? {
        guard let anchor = anchor(of: mode) else { return minimum }
        return DatePickerGridLogic.rangeMinimum(minimum, anchor: anchor)
    }

    /// The finished grid, six weeks of seven, with the floor already folded in — the view never
    /// gets the chance to draw a cell the floor should have closed.
    static func weeks(
        of month: DatePickerMonth,
        mode: DPDateFieldMode,
        minimum: DateOnly?,
        maximum: DateOnly?,
        today: Date = Date()
    ) -> [[DatePickerDay]] {
        let days = DatePickerGridLogic.monthGrid(
            year: month.year,
            month: month.month,
            minimum: lowerBound(mode: mode, minimum: minimum),
            maximum: maximum,
            today: today
        )
        return stride(from: 0, to: days.count, by: DatePickerGridLogic.daysPerWeek).map {
            Array(days[$0..<Swift.min($0 + DatePickerGridLogic.daysPerWeek, days.count)])
        }
    }

    static func tap(
        _ day: DateOnly,
        mode: DPDateFieldMode,
        minimum: DateOnly?,
        maximum: DateOnly?
    ) -> DPDateFieldTap {
        guard DatePickerGridLogic.isValidDay(day) else { return .ignored }
        let bound = lowerBound(mode: mode, minimum: minimum)
        guard !DatePickerGridLogic.isDisabled(day, minimum: bound, maximum: maximum) else { return .ignored }
        return anchor(of: mode) == nil ? .committed(day) : .staged(day)
    }

    /// Disabling the cells is only half the floor. Left reachable, the month before the anchor
    /// is a screen of dead days, so the control that would page to it switches off.
    static func canGoToPreviousMonth(
        from month: DatePickerMonth,
        mode: DPDateFieldMode,
        minimum: DateOnly?
    ) -> Bool {
        let bound = lowerBound(mode: mode, minimum: minimum)
        guard DatePickerGridLogic.isValidDay(bound) else { return true }
        guard let previous = DatePickerGridLogic.addingDays(-1, to: DatePickerGridLogic.firstDay(of: month))
        else { return false }
        return !DatePickerGridLogic.isDisabled(previous, minimum: bound)
    }

    static func canGoToNextMonth(from month: DatePickerMonth, maximum: DateOnly?) -> Bool {
        guard DatePickerGridLogic.isValidDay(maximum) else { return true }
        guard let next = DatePickerGridLogic.addingMonths(1, to: DatePickerGridLogic.firstDay(of: month))
        else { return false }
        return !DatePickerGridLogic.isDisabled(next, maximum: maximum)
    }

    /// The header shortcut navigates and nothing else, so it is offered exactly while today is a
    /// day the grid is allowed to show.
    static func canGoToToday(
        mode: DPDateFieldMode,
        minimum: DateOnly?,
        maximum: DateOnly?,
        today: Date = Date()
    ) -> Bool {
        !DatePickerGridLogic.isDisabled(
            DatePickerGridLogic.day(from: today),
            minimum: lowerBound(mode: mode, minimum: minimum),
            maximum: maximum
        )
    }

    /// The month the field opens on. A range field opens on the end it already carries and on
    /// the anchor otherwise, so the day the span is measured from is always on screen.
    static func openingMonth(
        mode: DPDateFieldMode,
        value: DateOnly,
        minimum: DateOnly?,
        maximum: DateOnly?,
        today: Date = Date()
    ) -> DatePickerMonth {
        guard let anchor = anchor(of: mode) else {
            return DatePickerGridLogic.initialMonth(
                selected: value,
                minimum: minimum,
                maximum: maximum,
                today: today
            )
        }
        let start = DatePickerGridLogic.isValidDay(value) ? value : anchor
        let focus = DatePickerGridLogic.clamped(
            start,
            minimum: lowerBound(mode: mode, minimum: minimum),
            maximum: maximum
        )
        return DatePickerGridLogic.month(of: focus)
            ?? DatePickerGridLogic.initialMonth(selected: nil, today: today)
    }

    /// Re-opening a range field shows the span it already committed — but only while that end is
    /// still reachable, so an anchor that has since moved past it cannot resurrect a day the
    /// user can no longer choose.
    static func openingStagedDay(
        mode: DPDateFieldMode,
        value: DateOnly,
        minimum: DateOnly?,
        maximum: DateOnly?
    ) -> DateOnly? {
        guard anchor(of: mode) != nil, DatePickerGridLogic.isValidDay(value) else { return nil }
        let bound = lowerBound(mode: mode, minimum: minimum)
        guard !DatePickerGridLogic.isDisabled(value, minimum: bound, maximum: maximum) else { return nil }
        return value
    }

    static func canConfirm(stagedDay: DateOnly?) -> Bool {
        DatePickerGridLogic.isValidDay(stagedDay)
    }

    static func rangeState(
        _ day: DateOnly,
        mode: DPDateFieldMode,
        stagedDay: DateOnly?
    ) -> DatePickerRangeState {
        guard let anchor = anchor(of: mode) else { return .none }
        return DatePickerGridLogic.rangeDayState(day, anchor: anchor, end: stagedDay)
    }

    /// The filled single cell: the committed day in `single` mode, the staged end in `range`.
    /// In range mode the block already paints the span, so this only drives the spoken trait.
    static func isSelected(
        _ day: DateOnly,
        mode: DPDateFieldMode,
        value: DateOnly,
        stagedDay: DateOnly?
    ) -> Bool {
        guard anchor(of: mode) == nil else { return stagedDay != nil && day == stagedDay }
        return DatePickerGridLogic.isValidDay(value) && day == value
    }

    /// The two ends are filled; the days between take the softer fill so the run reads as one
    /// bar with two heads rather than three separate marks.
    ///
    /// That softer fill is `accentSoftHover`, not `accentSoft`. `accentSoft` is a tint meant to
    /// sit behind text on the card, and in dark mode it is `#1E3A5F` on a `#1F2937` card — a
    /// 1.2:1 ratio, which leaves the middle of a span barely visible next to its two accent
    /// ends. `accentSoftHover` is the same family one step up and carries the block at 1.6:1.
    static func fill(state: DatePickerRangeState, isSelected: Bool) -> Color {
        switch state {
        case .middle:
            return DPColor.accentSoftHover
        case .start, .end, .single:
            return DPColor.accent
        case .none:
            return isSelected ? DPColor.accent : Color.clear
        }
    }

    static func foreground(
        state: DatePickerRangeState,
        isSelected: Bool,
        isCurrentMonth: Bool
    ) -> Color {
        switch state {
        case .middle:
            // A span running past the end of the month keeps its text colour: the block must not
            // fade where the grid switches to the next month's leading days.
            return DPColor.textPrimary
        case .start, .end, .single:
            return DPColor.textOnDark
        case .none:
            if isSelected { return DPColor.textOnDark }
            return isCurrentMonth ? DPColor.textPrimary : DPColor.textMuted
        }
    }

    /// Only the outer corners of a span survive. The inner edges are square so consecutive cells
    /// butt together into one shape instead of a row of separate pills.
    static func cornerRadii(state: DatePickerRangeState, radius: CGFloat) -> RectangleCornerRadii {
        switch state {
        case .start:
            return RectangleCornerRadii(topLeading: radius, bottomLeading: radius, bottomTrailing: 0, topTrailing: 0)
        case .end:
            return RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: radius, topTrailing: radius)
        case .middle:
            return RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0)
        case .none, .single:
            return RectangleCornerRadii(
                topLeading: radius,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            )
        }
    }

    /// The weekend colours the calendar screen's own weekday header uses, so the two grids read
    /// as one family. Column 0 is the first weekday of `CalendarDateSupport.calendar`, Sunday.
    static func weekdayColor(column: Int) -> Color {
        switch column {
        case 0:
            return DPColor.dangerHover
        case DatePickerGridLogic.daysPerWeek - 1:
            return DPColor.accentHover
        default:
            return DPColor.textPrimary
        }
    }
}

/// Strings for the field.
///
/// The component is meant to be shared beyond the Calendar feature, so its own keys are
/// namespaced `datePicker.*` and can move out of `Calendar.xcstrings` in one cut once a shared
/// catalog exists. Strings the app already has — "Today", "Cancel", "OK", "Start", "End" and the
/// locked reason — are reused rather than duplicated, so the two surfaces cannot drift apart.
nonisolated enum DPDateFieldLocalization {
    static let table = "Calendar"

    static func text(_ key: String, locale: Locale = AppLocalization.locale) -> String {
        AppLocalization.string(key, table: table, locale: locale)
    }

    static func placeholder(locale: Locale = AppLocalization.locale) -> String {
        text("datePicker.placeholder", locale: locale)
    }

    static func dialogLabel(isRange: Bool, locale: Locale = AppLocalization.locale) -> String {
        text(isRange ? "datePicker.range.dialogLabel" : "datePicker.dialogLabel", locale: locale)
    }

    static func rangeHint(locale: Locale = AppLocalization.locale) -> String {
        text("datePicker.range.hint", locale: locale)
    }

    /// Korean has no plural form and English does. The app uses no `.xcstrings` plural variations
    /// anywhere, and its one localization helper formats through `String(format:)`, which does
    /// not expand a stringsdict rule — so the two English forms are two keys and the choice is
    /// made here, where a test can see it.
    static func rangeDuration(days: Int, locale: Locale = AppLocalization.locale) -> String {
        let key = days == 1 ? "datePicker.range.duration.one" : "datePicker.range.duration.other"
        return AppLocalization.format(key, table: table, arguments: [days], locale: locale)
    }

    /// A locked field is not a control, so VoiceOver meets one element and has to hear both the
    /// date and why it cannot be changed.
    static func lockedAccessibilityValue(
        _ value: DateOnly,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let reason = text("calendar.schedule.start.locked", locale: locale)
        let day = DatePickerGridLogic.fieldLabel(value, locale: locale)
        return day.isEmpty ? reason : "\(day), \(reason)"
    }
}

/// The app's date-selection control, mirrored from
/// `frontend/src/components/common/DatePickerField.vue`.
///
/// The calendar expands **inline** rather than in a popover or a sheet. The first consumer sits
/// two presentations deep already (`fullScreenCover` → `DPModalOverlay` → `DPModalPanel`); a
/// third layer would put a backdrop between the user and the calendar whose tap closes the
/// editor rather than the calendar. `DPModalPanel` measures and scrolls its body, so a
/// disclosure that simply grows is the one that behaves.
struct DPDateField<Accessory: View>: View {
    @Binding private var value: DateOnly
    private let fieldName: String
    private let rowHeight: CGFloat
    private let mode: DPDateFieldMode
    private let minimum: DateOnly?
    private let maximum: DateOnly?
    private let isReadOnly: Bool
    private let placeholder: String?
    private let locale: Locale
    private let calendarLeadingBleed: CGFloat
    private let expansion: Binding<Bool>?
    private let accessory: Accessory

    /// Only used while no caller takes part in the state — see `expansion`.
    @State private var ownExpansion: Bool
    @State private var visibleMonth: DatePickerMonth
    /// Range mode only: the day a tap has proposed, still unwritten until confirm.
    @State private var stagedDay: DateOnly?
    @State private var today: Date

    @ScaledMetric(relativeTo: .body) private var dayCellHeight: CGFloat = DPDateFieldLayout.dayCellHeight
    @ScaledMetric(relativeTo: .caption2) private var weekdayHeaderHeight: CGFloat = DPDateFieldLayout.weekdayHeaderHeight
    @ScaledMetric(relativeTo: .caption) private var headerControlSize: CGFloat = DPDateFieldLayout.headerControlSize

    /// - Parameters:
    ///   - value: the committed day; `DateOnly("")` — or any value that is not a real day —
    ///     shows the placeholder. Tolerates a `.constant` binding, which is what a locked field
    ///     passes.
    ///   - fieldName: what VoiceOver calls this field, supplied by the row that owns the label.
    ///   - rowHeight: the height the collapsed row must hold, so the form keeps owning its own
    ///     `@ScaledMetric` and the row cannot shift when a neighbouring control changes shape.
    ///   - calendarLeadingBleed: how far past its own leading edge the expanded calendar may
    ///     reach. A form row hands its label column here so the grid is not charged for it;
    ///     zero — the default — keeps the calendar inside the field's own column.
    ///   - expansion: the calendar's open state, when the caller has to take part in it. A modal
    ///     whose backdrop tap must close the calendar rather than the whole screen needs both to
    ///     read the state and to write it, so it passes a binding and the field's own state
    ///     steps aside; everyone else passes nothing and the field keeps the state to itself.
    ///     Closing the calendar this way discards a staged range exactly as cancelling does.
    ///   - initiallyExpanded: opens the calendar without a tap. For previews and tests only;
    ///     production callers always start collapsed. Ignored when `expansion` is supplied,
    ///     which is the caller's to seed.
    ///   - accessory: a control that shares the collapsed row, such as the schedule form's
    ///     optional time. It sits beside the field rather than under it so a row that has
    ///     nothing to show there leaves invisible space inside the row instead of an empty band
    ///     beneath it.
    init(
        value: Binding<DateOnly>,
        fieldName: String,
        rowHeight: CGFloat,
        mode: DPDateFieldMode = .single,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil,
        isReadOnly: Bool = false,
        placeholder: String? = nil,
        locale: Locale = AppLocalization.locale,
        calendarLeadingBleed: CGFloat = 0,
        expansion: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        _value = value
        self.fieldName = fieldName
        self.rowHeight = rowHeight
        self.mode = mode
        self.minimum = minimum
        self.maximum = maximum
        self.isReadOnly = isReadOnly
        self.placeholder = placeholder
        self.locale = locale
        self.calendarLeadingBleed = calendarLeadingBleed
        self.expansion = expansion
        self.accessory = accessory()

        let now = Date()
        let opensExpanded = (expansion?.wrappedValue ?? initiallyExpanded) && !isReadOnly
        _today = State(initialValue: now)
        _ownExpansion = State(initialValue: opensExpanded)
        _visibleMonth = State(initialValue: DPDateFieldPolicy.openingMonth(
            mode: mode,
            value: value.wrappedValue,
            minimum: minimum,
            maximum: maximum,
            today: now
        ))
        _stagedDay = State(initialValue: opensExpanded
            ? DPDateFieldPolicy.openingStagedDay(
                mode: mode,
                value: value.wrappedValue,
                minimum: minimum,
                maximum: maximum
            )
            : nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                if isReadOnly {
                    lockedRow
                } else {
                    trigger
                }
                accessory
            }
            if isExpanded, !isReadOnly {
                calendar
                    // The row owes its label column the space; the grid inside the calendar does
                    // not. Negative padding hands the calendar the column back without changing
                    // the width this field reports, so nothing around it moves.
                    .padding(.leading, -max(0, calendarLeadingBleed))
            }
        }
        .onChange(of: isReadOnly) { _, locked in
            if locked { collapse() }
        }
        // Closing is closing however it was asked for, including from outside: a caller that
        // drives `expansion` shuts the calendar without going through the footer.
        .onChange(of: isExpanded) { _, expanded in
            if !expanded { stagedDay = nil }
        }
        .onChange(of: DPDateFieldPolicy.lowerBound(mode: mode, minimum: minimum)) { _, bound in
            // An anchor that moves under an open calendar must not leave a staged day behind it.
            if let staged = stagedDay,
               DatePickerGridLogic.isDisabled(staged, minimum: bound, maximum: maximum) {
                stagedDay = nil
            }
        }
    }

    // MARK: - The collapsed row

    /// Both states of the row draw this one box, so "same size, same radius, same font" holds by
    /// construction and only colour, edge and glyph are left to say which state it is in.
    private func fieldBox(
        foreground: Color,
        background: Color,
        border: Color,
        borderStyle: StrokeStyle,
        trailingSymbol: String
    ) -> some View {
        HStack(spacing: DPSpacing.extraSmall) {
            Text(displayText)
                .font(DPFont.light(size: DPDateFieldLayout.fieldFontSize, relativeTo: .subheadline))
                .foregroundStyle(hasValue ? foreground : DPColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Image(systemName: trailingSymbol)
                .font(.system(size: DPDateFieldLayout.fieldIconSize, weight: .semibold))
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.horizontal, DPChrome.inputHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: rowHeight)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .strokeBorder(border, style: borderStyle)
        }
        .contentShape(Rectangle())
    }

    private var trigger: some View {
        Button {
            toggle()
        } label: {
            fieldBox(
                foreground: DPColor.textPrimary,
                background: DPColor.backgroundInput,
                border: isExpanded ? DPColor.accent : DPColor.borderInput,
                borderStyle: StrokeStyle(
                    lineWidth: isExpanded ? DPChrome.focusRingWidth : DPChrome.borderWidth
                ),
                trailingSymbol: "calendar"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fieldName)
        .accessibilityValue(displayText)
    }

    /// A locked field is not a control: it keeps the editable box exactly and differs by *state*
    /// alone — muted, dashed, badged with a lock, opening nothing. Nothing about it may suggest
    /// a press, so it is not a button, and VoiceOver is handed one flattened element that says
    /// the field, the date and the reason instead of an adjustable date picker it cannot adjust.
    private var lockedRow: some View {
        fieldBox(
            foreground: DPColor.textMuted,
            background: DPColor.backgroundTertiary,
            border: DPColor.borderSecondary,
            borderStyle: StrokeStyle(lineWidth: DPChrome.borderWidth, dash: [4, 3]),
            trailingSymbol: "lock.fill"
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fieldName)
        .accessibilityValue(DPDateFieldLocalization.lockedAccessibilityValue(value, locale: locale))
    }

    // MARK: - The calendar

    private var calendar: some View {
        VStack(spacing: DPSpacing.small) {
            header
            grid
            if isRange {
                footer
            }
        }
        .padding(DPSpacing.small)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .strokeBorder(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DPDateFieldLocalization.dialogLabel(isRange: isRange, locale: locale))
    }

    /// The way back to today sits with the month arrows, where a calendar is expected to keep
    /// it. It moves the view and nothing else: it never selects and never closes, so it cannot
    /// slip a value past the confirm step.
    private var header: some View {
        HStack(spacing: DPSpacing.extraSmall) {
            Text(DatePickerGridLogic.monthLabel(
                year: visibleMonth.year,
                month: visibleMonth.month,
                locale: locale
            ))
                .font(DPFont.bold(size: DPDateFieldLayout.monthTitleFontSize, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            Button {
                goToToday()
            } label: {
                Text(DPDateFieldLocalization.text("calendar.today", locale: locale))
                    .font(DPFont.bold(size: DPDateFieldLayout.todayFontSize, relativeTo: .caption))
                    .foregroundStyle(DPColor.accent)
                    .padding(.horizontal, DPSpacing.small)
                    .frame(height: headerControlSize)
                    .background(DPColor.accentSoft)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToToday)
            .opacity(canGoToToday ? 1 : DPChrome.disabledOpacity)
            .accessibilityLabel(DPDateFieldLocalization.text("datePicker.goToToday", locale: locale))

            monthStep(symbol: "chevron.left", labelKey: "datePicker.previousMonth", isEnabled: canGoToPreviousMonth, delta: -1)
            monthStep(symbol: "chevron.right", labelKey: "datePicker.nextMonth", isEnabled: canGoToNextMonth, delta: 1)
        }
    }

    private func monthStep(symbol: String, labelKey: String, isEnabled: Bool, delta: Int) -> some View {
        Button {
            shiftMonth(delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: DPDateFieldLayout.navigationIconSize, weight: .semibold))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: headerControlSize, height: headerControlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
        .accessibilityLabel(DPDateFieldLocalization.text(labelKey, locale: locale))
    }

    private var grid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(
                    Array(DatePickerGridLogic.weekdayLabels(locale: locale).enumerated()),
                    id: \.offset
                ) { column, label in
                    Text(label)
                        .font(DPFont.bold(size: DPDateFieldLayout.weekdayFontSize, relativeTo: .caption2))
                        .foregroundStyle(DPDateFieldPolicy.weekdayColor(column: column))
                        .frame(maxWidth: .infinity)
                        .frame(height: weekdayHeaderHeight)
                }
            }

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                // No spacing between the cells: the span has to close up into one shape.
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: DatePickerDay) -> some View {
        let state = DPDateFieldPolicy.rangeState(day.date, mode: mode, stagedDay: stagedDay)
        let isSelected = DPDateFieldPolicy.isSelected(
            day.date,
            mode: mode,
            value: value,
            stagedDay: stagedDay
        )
        let isPainted = state != .none || isSelected

        return Button {
            select(day.date)
        } label: {
            Text(verbatim: "\(day.day)")
                .font(isPainted || day.isToday
                    ? DPFont.bold(size: DPDateFieldLayout.dayFontSize, relativeTo: .footnote)
                    : DPFont.light(size: DPDateFieldLayout.dayFontSize, relativeTo: .footnote))
                .foregroundStyle(DPDateFieldPolicy.foreground(
                    state: state,
                    isSelected: isSelected,
                    isCurrentMonth: day.isCurrentMonth
                ))
                .frame(maxWidth: .infinity)
                .frame(height: dayCellHeight)
                .background {
                    UnevenRoundedRectangle(
                        cornerRadii: DPDateFieldPolicy.cornerRadii(
                            state: state,
                            radius: DPDateFieldLayout.dayCornerRadius
                        ),
                        style: .continuous
                    )
                    .fill(DPDateFieldPolicy.fill(state: state, isSelected: isSelected))
                }
                .overlay {
                    // Today is ringed rather than boxed: these cells are rounded, so the
                    // calendar screen's square 2-point stroke would sit off the shape. The web
                    // picker and `DPYearMonthPicker` both mark it this way.
                    if day.isToday, !isPainted {
                        RoundedRectangle(
                            cornerRadius: DPDateFieldLayout.dayCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(DPColor.accentBorder, lineWidth: DPChrome.focusRingWidth)
                    }
                }
                .opacity(day.isDisabled ? DPChrome.disabledOpacity : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.isDisabled)
        .accessibilityLabel(DatePickerGridLogic.dayAccessibilityLabel(day.date, locale: locale))
        .accessibilityAddTraits(isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }

    // MARK: - The range footer

    private var footer: some View {
        VStack(spacing: DPSpacing.extraSmall) {
            HStack(spacing: DPSpacing.extraSmall) {
                summaryLeg(
                    title: DPDateFieldLocalization.text("calendar.schedule.start", locale: locale),
                    value: anchorLabel,
                    isEmpty: false
                )
                Image(systemName: "arrow.right")
                    .font(.system(size: DPDateFieldLayout.summaryLabelFontSize, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .accessibilityHidden(true)
                summaryLeg(
                    title: DPDateFieldLocalization.text("calendar.schedule.end", locale: locale),
                    value: stagedLabel ?? "—",
                    isEmpty: stagedLabel == nil
                )
            }

            // A bare line of text under the summary read as a stray word left behind by the
            // wrap that put it there. The count is the answer to the two dates above it, so it
            // is drawn as one: a chip, centred under the pair, tinted once there is a span to
            // count and plain while it is still only the hint.
            Text(durationText)
                .font(DPFont.bold(size: DPDateFieldLayout.durationFontSize, relativeTo: .caption))
                .foregroundStyle(canConfirm ? DPColor.accent : DPColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, DPSpacing.small)
                .padding(.vertical, DPSpacing.extraSmall / 2)
                .background(canConfirm ? DPColor.accentSoft : Color.clear)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.updatesFrequently)

            HStack(spacing: DPSpacing.small) {
                // Cancelling is also how a staged day is thrown away; nothing has reached the
                // binding, so there is nothing to undo.
                Button {
                    collapse()
                } label: {
                    Text(DPDateFieldLocalization.text("calendar.cancel", locale: locale))
                }
                .buttonStyle(DPOutlineButtonStyle())
                .frame(maxWidth: .infinity)

                Button {
                    confirm()
                } label: {
                    Text(DPDateFieldLocalization.text("calendar.ok", locale: locale))
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(!canConfirm)
            }
        }
        .padding(.top, DPSpacing.small)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DPColor.borderPrimary)
                .frame(height: DPChrome.borderWidth)
        }
    }

    private func summaryLeg(title: String, value: String, isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(DPFont.bold(size: DPDateFieldLayout.summaryLabelFontSize, relativeTo: .caption2))
                .foregroundStyle(DPColor.textMuted)
            Text(value)
                .font(DPFont.bold(size: DPDateFieldLayout.summaryValueFontSize, relativeTo: .footnote))
                .foregroundStyle(isEmpty ? DPColor.textMuted : DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived state

    private var isRange: Bool { DPDateFieldPolicy.anchor(of: mode) != nil }

    private var hasValue: Bool { DatePickerGridLogic.isValidDay(value) }

    private var displayText: String {
        hasValue
            ? DatePickerGridLogic.fieldLabel(value, locale: locale)
            : (placeholder ?? DPDateFieldLocalization.placeholder(locale: locale))
    }

    private var anchorLabel: String {
        DatePickerGridLogic.fieldLabel(DPDateFieldPolicy.anchor(of: mode), locale: locale)
    }

    private var stagedLabel: String? {
        guard let stagedDay, DatePickerGridLogic.isValidDay(stagedDay) else { return nil }
        return DatePickerGridLogic.fieldLabel(stagedDay, locale: locale)
    }

    private var canConfirm: Bool { DPDateFieldPolicy.canConfirm(stagedDay: stagedDay) }

    private var durationText: String {
        guard canConfirm else { return DPDateFieldLocalization.rangeHint(locale: locale) }
        return DPDateFieldLocalization.rangeDuration(
            days: DatePickerGridLogic.inclusiveDayCount(
                from: DPDateFieldPolicy.anchor(of: mode),
                to: stagedDay
            ),
            locale: locale
        )
    }

    private var weeks: [[DatePickerDay]] {
        DPDateFieldPolicy.weeks(
            of: visibleMonth,
            mode: mode,
            minimum: minimum,
            maximum: maximum,
            today: today
        )
    }

    private var canGoToPreviousMonth: Bool {
        DPDateFieldPolicy.canGoToPreviousMonth(from: visibleMonth, mode: mode, minimum: minimum)
    }

    private var canGoToNextMonth: Bool {
        DPDateFieldPolicy.canGoToNextMonth(from: visibleMonth, maximum: maximum)
    }

    private var canGoToToday: Bool {
        DPDateFieldPolicy.canGoToToday(mode: mode, minimum: minimum, maximum: maximum, today: today)
    }

    /// One reading of the open state whoever owns it, so nothing inside the field has to know
    /// whether a caller is taking part.
    private var isExpanded: Bool { expansion?.wrappedValue ?? ownExpansion }

    // MARK: - Actions

    private func setExpanded(_ expanded: Bool) {
        if let expansion {
            expansion.wrappedValue = expanded
        } else {
            ownExpansion = expanded
        }
    }

    private func toggle() {
        isExpanded ? collapse() : expand()
    }

    private func expand() {
        let now = Date()
        today = now
        visibleMonth = DPDateFieldPolicy.openingMonth(
            mode: mode,
            value: value,
            minimum: minimum,
            maximum: maximum,
            today: now
        )
        stagedDay = DPDateFieldPolicy.openingStagedDay(
            mode: mode,
            value: value,
            minimum: minimum,
            maximum: maximum
        )
        setExpanded(true)
    }

    /// Closing is also how a staged range is discarded, whichever way it was closed.
    private func collapse() {
        setExpanded(false)
        stagedDay = nil
    }

    private func select(_ day: DateOnly) {
        switch DPDateFieldPolicy.tap(day, mode: mode, minimum: minimum, maximum: maximum) {
        case .ignored:
            return
        case let .staged(day):
            stagedDay = day
        case let .committed(day):
            value = day
            collapse()
        }
    }

    private func confirm() {
        guard let stagedDay, canConfirm else { return }
        value = stagedDay
        collapse()
    }

    private func shiftMonth(_ delta: Int) {
        guard let moved = DatePickerGridLogic.addingMonths(
            delta,
            to: DatePickerGridLogic.firstDay(of: visibleMonth)
        ),
            let month = DatePickerGridLogic.month(of: moved)
        else { return }
        visibleMonth = month
    }

    private func goToToday() {
        guard canGoToToday,
              let month = DatePickerGridLogic.month(of: DatePickerGridLogic.day(from: today))
        else { return }
        visibleMonth = month
    }
}

/// The field on its own, for the callers with nothing to put beside it. Swift cannot default a
/// generic parameter, so the plain form is an initializer rather than a default argument.
extension DPDateField where Accessory == EmptyView {
    init(
        value: Binding<DateOnly>,
        fieldName: String,
        rowHeight: CGFloat,
        mode: DPDateFieldMode = .single,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil,
        isReadOnly: Bool = false,
        placeholder: String? = nil,
        locale: Locale = AppLocalization.locale,
        calendarLeadingBleed: CGFloat = 0,
        expansion: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false
    ) {
        self.init(
            value: value,
            fieldName: fieldName,
            rowHeight: rowHeight,
            mode: mode,
            minimum: minimum,
            maximum: maximum,
            isReadOnly: isReadOnly,
            placeholder: placeholder,
            locale: locale,
            calendarLeadingBleed: calendarLeadingBleed,
            expansion: expansion,
            initiallyExpanded: initiallyExpanded,
            accessory: { EmptyView() }
        )
    }
}

#if DEBUG
private struct DPDateFieldPreviewHost: View {
    let title: String
    let mode: DPDateFieldMode
    let locale: Locale
    let isReadOnly: Bool
    let initiallyExpanded: Bool
    @State var value: DateOnly

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(title)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            DPDateField(
                value: $value,
                fieldName: title,
                rowHeight: CalendarVisualLogic.scheduleDateRowHeight,
                mode: mode,
                isReadOnly: isReadOnly,
                locale: locale,
                initiallyExpanded: initiallyExpanded
            )
        }
        .padding(DPSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DPColor.backgroundSecondary)
    }
}

#Preview("Single · Light · English") {
    DPDateFieldPreviewHost(
        title: "Due date",
        mode: .single,
        locale: Locale(identifier: "en"),
        isReadOnly: false,
        initiallyExpanded: true,
        value: DateOnly(rawValue: "2026-08-24")
    )
}

#Preview("Single · Dark · Korean") {
    DPDateFieldPreviewHost(
        title: "마감일",
        mode: .single,
        locale: Locale(identifier: "ko"),
        isReadOnly: false,
        initiallyExpanded: true,
        value: DateOnly(rawValue: "")
    )
    .preferredColorScheme(.dark)
}

#Preview("Range · Staged span · Light · Korean") {
    DPDateFieldPreviewHost(
        title: "종료",
        mode: .range(anchor: DateOnly(rawValue: "2026-08-20")),
        locale: Locale(identifier: "ko"),
        isReadOnly: false,
        initiallyExpanded: true,
        value: DateOnly(rawValue: "2026-08-24")
    )
}

#Preview("Range · Month boundary · Dark · English") {
    DPDateFieldPreviewHost(
        title: "End",
        mode: .range(anchor: DateOnly(rawValue: "2026-12-30")),
        locale: Locale(identifier: "en"),
        isReadOnly: false,
        initiallyExpanded: true,
        value: DateOnly(rawValue: "2027-01-02")
    )
    .preferredColorScheme(.dark)
}

/// The shape the schedule form actually uses: a label column the row hangs off, a time control
/// sharing the row, and a calendar that bleeds back across the label so its seven columns are
/// not charged for it.
private struct DPDateFieldFormRowPreviewHost: View {
    let locale: Locale
    let hasTime: Bool
    @State var value: DateOnly

    private var labelWidth: CGFloat { CalendarVisualLogic.formLabelWidth(locale: locale) }

    var body: some View {
        HStack(alignment: .top, spacing: DPSpacing.small) {
            Text(locale.language.languageCode?.identifier == "ko" ? "종료" : "End")
                .font(DPFont.light(size: 13, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.top, 10)
            DPDateField(
                value: $value,
                fieldName: "End",
                rowHeight: CalendarVisualLogic.scheduleDateRowHeight,
                mode: .range(anchor: DateOnly(rawValue: "2026-08-20")),
                minimum: DateOnly(rawValue: "2026-08-20"),
                locale: locale,
                calendarLeadingBleed: CalendarVisualLogic.formRowContentInset(labelWidth: labelWidth),
                initiallyExpanded: true
            ) {
                if hasTime {
                    DatePicker(
                        "",
                        selection: .constant(Date()),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, locale)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: CalendarVisualLogic.scheduleDateRowHeight, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DPColor.backgroundModal)
    }
}

#Preview("Form row · Dark · Korean") {
    DPDateFieldFormRowPreviewHost(
        locale: Locale(identifier: "ko"),
        hasTime: true,
        value: DateOnly(rawValue: "2026-08-25")
    )
    .preferredColorScheme(.dark)
}

#Preview("Form row · Light · English") {
    DPDateFieldFormRowPreviewHost(
        locale: Locale(identifier: "en"),
        hasTime: false,
        value: DateOnly(rawValue: "")
    )
}

#Preview("Read-only · Light · English") {
    DPDateFieldPreviewHost(
        title: "Start",
        mode: .single,
        locale: Locale(identifier: "en"),
        isReadOnly: true,
        initiallyExpanded: false,
        value: DateOnly(rawValue: "2026-08-20")
    )
}

#Preview("Read-only · Dark · Korean") {
    DPDateFieldPreviewHost(
        title: "시작",
        mode: .single,
        locale: Locale(identifier: "ko"),
        isReadOnly: true,
        initiallyExpanded: false,
        value: DateOnly(rawValue: "2026-08-20")
    )
    .preferredColorScheme(.dark)
}
#endif
