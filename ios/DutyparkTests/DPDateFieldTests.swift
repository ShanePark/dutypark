import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Dutypark

/// The native counterpart of `frontend/src/components/common/DatePickerField.vue`.
///
/// The grid arithmetic is already covered by `DatePickerGridLogicTests`; what is covered here
/// is the field itself — the single/range split, the anchor floor, the hotel-style block, the
/// footer summary and the locked state — plus the few platform facts (inline expansion, the
/// reserved row height, token-only colour) that can only be read off the source.
@MainActor
struct DPDateFieldTests {
    private func value(_ raw: String) -> DateOnly { DateOnly(rawValue: raw) }

    private func date(_ raw: String) throws -> Date {
        try #require(CalendarDateSupport.date(from: DateOnly(rawValue: raw)))
    }

    private static let anchorRaw = "2026-08-20"

    private var anchor: DateOnly { value(Self.anchorRaw) }
    private var rangeMode: DPDateFieldMode { .range(anchor: anchor) }

    // MARK: - Mode

    /// The anchor is what turns the field into a range picker at all, so an anchor that is not
    /// a real day has to degrade to the single-tap field rather than to a grid with no floor.
    @Test
    func rangeModeNeedsAUsableAnchorAndOtherwiseBehavesAsTheSingleField() {
        #expect(DPDateFieldPolicy.anchor(of: .single) == nil)
        #expect(DPDateFieldPolicy.anchor(of: rangeMode) == anchor)
        #expect(DPDateFieldPolicy.anchor(of: .range(anchor: value("2026-02-30"))) == nil)
        #expect(DPDateFieldPolicy.anchor(of: .range(anchor: value(""))) == nil)
    }

    // MARK: - Committing versus staging

    /// The whole point of the split: a single-mode tap is the answer, a range-mode tap is only
    /// a proposal that the footer's confirm turns into one.
    @Test
    func aTapCommitsInSingleModeAndOnlyStagesInRangeMode() {
        let day = value("2026-08-24")

        #expect(DPDateFieldPolicy.tap(day, mode: .single, minimum: nil, maximum: nil) == .committed(day))
        #expect(DPDateFieldPolicy.tap(day, mode: rangeMode, minimum: nil, maximum: nil) == .staged(day))
    }

    /// The floor is not a validation run on submit: a day before the anchor answers nothing at
    /// all, so it can neither be committed nor staged.
    @Test
    func everyDayBeforeTheAnchorIsUntappable() {
        for raw in ["2026-08-19", "2026-07-31", "2025-01-01"] {
            #expect(
                DPDateFieldPolicy.tap(value(raw), mode: rangeMode, minimum: nil, maximum: nil) == .ignored,
                "\(raw) sits before the anchor"
            )
        }
        #expect(DPDateFieldPolicy.tap(anchor, mode: rangeMode, minimum: nil, maximum: nil) == .staged(anchor))
    }

    @Test
    func theCallerBoundsStillCloseTheGridInBothModes() {
        let minimum = value("2026-08-10")
        let maximum = value("2026-08-25")

        #expect(DPDateFieldPolicy.tap(value("2026-08-09"), mode: .single, minimum: minimum, maximum: maximum) == .ignored)
        #expect(DPDateFieldPolicy.tap(value("2026-08-26"), mode: .single, minimum: minimum, maximum: maximum) == .ignored)
        #expect(DPDateFieldPolicy.tap(value("2026-08-26"), mode: rangeMode, minimum: minimum, maximum: maximum) == .ignored)
        #expect(DPDateFieldPolicy.tap(value("2026-08-25"), mode: rangeMode, minimum: minimum, maximum: maximum) == .staged(value("2026-08-25")))
        #expect(DPDateFieldPolicy.tap(value("nonsense"), mode: .single, minimum: nil, maximum: nil) == .ignored)
    }

    /// One lower bound drives disabling, month paging and the today control, so the anchor and
    /// the caller's own minimum have to be composed in exactly one place.
    @Test
    func theAnchorJoinsTheCallerMinimumAsTheOneGridFloor() {
        #expect(DPDateFieldPolicy.lowerBound(mode: rangeMode, minimum: nil) == anchor)
        #expect(DPDateFieldPolicy.lowerBound(mode: rangeMode, minimum: value("2026-08-01")) == anchor)
        #expect(DPDateFieldPolicy.lowerBound(mode: rangeMode, minimum: value("2026-09-01")) == value("2026-09-01"))
        #expect(DPDateFieldPolicy.lowerBound(mode: .single, minimum: value("2026-08-01")) == value("2026-08-01"))
        #expect(DPDateFieldPolicy.lowerBound(mode: .single, minimum: nil) == nil)
    }

    // MARK: - Month paging

    /// Disabling the cells is only half the floor: a user who can page back to July is looking
    /// at a month of dead cells, so the control that would take them there switches off.
    @Test
    func monthPagingStopsAtTheAnchorsOwnMonth() {
        let august = DatePickerMonth(year: 2026, month: 8)
        let september = DatePickerMonth(year: 2026, month: 9)

        #expect(DPDateFieldPolicy.canGoToPreviousMonth(from: august, mode: rangeMode, minimum: nil) == false)
        #expect(DPDateFieldPolicy.canGoToPreviousMonth(from: september, mode: rangeMode, minimum: nil))
        #expect(DPDateFieldPolicy.canGoToPreviousMonth(from: august, mode: .single, minimum: nil))
        #expect(
            DPDateFieldPolicy.canGoToPreviousMonth(from: september, mode: .single, minimum: value("2026-09-01")) == false
        )
    }

    @Test
    func monthPagingStopsAtTheMaximumsOwnMonth() {
        let august = DatePickerMonth(year: 2026, month: 8)

        #expect(DPDateFieldPolicy.canGoToNextMonth(from: august, maximum: nil))
        #expect(DPDateFieldPolicy.canGoToNextMonth(from: august, maximum: value("2026-08-31")) == false)
        #expect(DPDateFieldPolicy.canGoToNextMonth(from: august, maximum: value("2026-09-01")))
    }

    /// The header shortcut only navigates, so it has to be shut off exactly when today is not a
    /// month the grid may show — which in range mode means an anchor in the future.
    @Test
    func todayIsOnlyOfferedWhileItIsInsideTheBounds() throws {
        let today = try date("2026-08-20")

        #expect(DPDateFieldPolicy.canGoToToday(mode: .single, minimum: nil, maximum: nil, today: today))
        #expect(DPDateFieldPolicy.canGoToToday(mode: rangeMode, minimum: nil, maximum: nil, today: today))
        #expect(
            DPDateFieldPolicy.canGoToToday(
                mode: .range(anchor: value("2027-01-10")),
                minimum: nil,
                maximum: nil,
                today: today
            ) == false
        )
        #expect(
            DPDateFieldPolicy.canGoToToday(mode: .single, minimum: nil, maximum: value("2026-08-19"), today: today) == false
        )
    }

    // MARK: - Grid

    /// The view draws whatever this hands it, so the floor has to be folded in here rather than
    /// left to a second call the view could forget.
    @Test
    func theGridArrivesAsSixWeeksWithTheAnchorFloorAlreadyApplied() throws {
        let weeks = DPDateFieldPolicy.weeks(
            of: DatePickerMonth(year: 2026, month: 8),
            mode: rangeMode,
            minimum: nil,
            maximum: nil,
            today: try date("2026-08-20")
        )

        #expect(weeks.count == DatePickerGridLogic.weeksPerGrid)
        #expect(weeks.allSatisfy { $0.count == DatePickerGridLogic.daysPerWeek })

        let days = weeks.flatMap { $0 }
        let cell = { (raw: String) in days.first { $0.date == self.value(raw) } }
        #expect(cell("2026-08-19")?.isDisabled == true)
        #expect(cell("2026-07-30")?.isDisabled == true)
        #expect(cell("2026-08-20")?.isDisabled == false)
        #expect(cell("2026-09-05")?.isDisabled == false)
        #expect(days.filter(\.isToday).count == 1)
    }

    // MARK: - The hotel-style block

    /// Check-in and check-out are filled; the nights between them take the softer fill and keep
    /// the primary text colour, so the span reads as one bar rather than a run of pills.
    @Test
    func aStagedSpanPaintsOneContinuousBlock() {
        #expect(DPDateFieldPolicy.fill(state: .start, isSelected: false) == DPColor.accent)
        #expect(DPDateFieldPolicy.fill(state: .end, isSelected: false) == DPColor.accent)
        #expect(DPDateFieldPolicy.fill(state: .single, isSelected: false) == DPColor.accent)
        #expect(DPDateFieldPolicy.fill(state: .middle, isSelected: false) == DPColor.accentSoftHover)
        #expect(DPDateFieldPolicy.fill(state: .none, isSelected: false) == Color.clear)

        #expect(DPDateFieldPolicy.foreground(state: .start, isSelected: false, isCurrentMonth: true) == DPColor.textOnDark)
        #expect(DPDateFieldPolicy.foreground(state: .middle, isSelected: false, isCurrentMonth: true) == DPColor.textPrimary)
        // A span that runs off the end of the month keeps painting: the block cannot break
        // where the grid switches to the next month's leading days.
        #expect(DPDateFieldPolicy.foreground(state: .middle, isSelected: false, isCurrentMonth: false) == DPColor.textPrimary)
        #expect(DPDateFieldPolicy.foreground(state: .none, isSelected: false, isCurrentMonth: false) == DPColor.textMuted)
        #expect(DPDateFieldPolicy.foreground(state: .none, isSelected: false, isCurrentMonth: true) == DPColor.textPrimary)
    }

    /// Only the outer corners of the span survive; the inner edges are square so consecutive
    /// cells butt together into one shape.
    @Test
    func onlyTheOuterCornersOfASpanAreRounded() {
        let radius: CGFloat = 8

        #expect(
            DPDateFieldPolicy.cornerRadii(state: .start, radius: radius)
                == RectangleCornerRadii(topLeading: radius, bottomLeading: radius, bottomTrailing: 0, topTrailing: 0)
        )
        #expect(
            DPDateFieldPolicy.cornerRadii(state: .end, radius: radius)
                == RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: radius, topTrailing: radius)
        )
        #expect(
            DPDateFieldPolicy.cornerRadii(state: .middle, radius: radius)
                == RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0)
        )
    }

    @Test
    func aOneDaySpanCollapsesToASingleRoundedCell() {
        let radius: CGFloat = 8
        let rounded = RectangleCornerRadii(
            topLeading: radius,
            bottomLeading: radius,
            bottomTrailing: radius,
            topTrailing: radius
        )

        #expect(DPDateFieldPolicy.cornerRadii(state: .single, radius: radius) == rounded)
        #expect(DPDateFieldPolicy.cornerRadii(state: .none, radius: radius) == rounded)
        #expect(
            DPDateFieldPolicy.rangeState(anchor, mode: rangeMode, stagedDay: anchor) == .single
        )
    }

    /// Nothing is painted until a day is staged, and the state the view asks for is the one the
    /// shared grid policy answers.
    @Test
    func theBlockOnlyExistsInRangeModeAndOnlyOnceADayIsStaged() {
        let end = value("2026-08-24")

        #expect(DPDateFieldPolicy.rangeState(end, mode: rangeMode, stagedDay: nil) == .none)
        #expect(DPDateFieldPolicy.rangeState(end, mode: .single, stagedDay: end) == .none)
        #expect(DPDateFieldPolicy.rangeState(anchor, mode: rangeMode, stagedDay: end) == .start)
        #expect(DPDateFieldPolicy.rangeState(value("2026-08-22"), mode: rangeMode, stagedDay: end) == .middle)
        #expect(DPDateFieldPolicy.rangeState(end, mode: rangeMode, stagedDay: end) == .end)
    }

    /// In single mode there is no span, so the committed day is the one filled cell and it keeps
    /// all four corners.
    @Test
    func theCommittedDayInSingleModeIsAFilledRoundedCell() {
        let day = value("2026-08-24")

        #expect(DPDateFieldPolicy.isSelected(day, mode: .single, value: day, stagedDay: nil))
        #expect(DPDateFieldPolicy.isSelected(day, mode: .single, value: value("2026-08-25"), stagedDay: nil) == false)
        #expect(DPDateFieldPolicy.isSelected(day, mode: rangeMode, value: day, stagedDay: nil) == false)
        #expect(DPDateFieldPolicy.isSelected(day, mode: rangeMode, value: value(""), stagedDay: day))

        #expect(DPDateFieldPolicy.fill(state: .none, isSelected: true) == DPColor.accent)
        #expect(DPDateFieldPolicy.foreground(state: .none, isSelected: true, isCurrentMonth: false) == DPColor.textOnDark)
    }

    // MARK: - Footer

    /// The summary counts nights the way a hotel does — both ends included — and English needs
    /// its singular.
    @Test
    func theFooterCountsBothEndsAndPluralisesInEnglish() {
        let english = Locale(identifier: "en")
        let korean = Locale(identifier: "ko")

        #expect(DPDateFieldLocalization.rangeDuration(days: 1, locale: english) == "1 day")
        #expect(DPDateFieldLocalization.rangeDuration(days: 2, locale: english) == "2 days")
        #expect(DPDateFieldLocalization.rangeDuration(days: 5, locale: english) == "5 days")
        #expect(DPDateFieldLocalization.rangeDuration(days: 1, locale: korean) == "1일")
        #expect(DPDateFieldLocalization.rangeDuration(days: 5, locale: korean) == "5일")

        #expect(DatePickerGridLogic.inclusiveDayCount(from: anchor, to: value("2026-08-24")) == 5)
    }

    @Test
    func confirmIsOnlyOfferedOnceADayIsStaged() {
        #expect(DPDateFieldPolicy.canConfirm(stagedDay: nil) == false)
        #expect(DPDateFieldPolicy.canConfirm(stagedDay: value("")) == false)
        #expect(DPDateFieldPolicy.canConfirm(stagedDay: value("2026-08-24")))
    }

    // MARK: - Opening

    @Test
    func openingLandsOnTheMonthTheUserIsAboutToWorkIn() throws {
        let today = try date("2026-08-20")

        #expect(
            DPDateFieldPolicy.openingMonth(mode: .single, value: value("2026-03-14"), minimum: nil, maximum: nil, today: today)
                == DatePickerMonth(year: 2026, month: 3)
        )
        #expect(
            DPDateFieldPolicy.openingMonth(mode: .single, value: value(""), minimum: nil, maximum: nil, today: today)
                == DatePickerMonth(year: 2026, month: 8)
        )
        // A range picker opens on the staged end when the field already carries one, and on the
        // anchor otherwise, so the span's start is always on screen.
        #expect(
            DPDateFieldPolicy.openingMonth(
                mode: .range(anchor: value("2026-12-30")),
                value: value("2027-01-04"),
                minimum: nil,
                maximum: nil,
                today: today
            ) == DatePickerMonth(year: 2027, month: 1)
        )
        #expect(
            DPDateFieldPolicy.openingMonth(
                mode: .range(anchor: value("2026-12-30")),
                value: value(""),
                minimum: nil,
                maximum: nil,
                today: today
            ) == DatePickerMonth(year: 2026, month: 12)
        )
    }

    /// Re-opening a range field shows the span it already committed; a stale value the anchor
    /// has since overtaken must not come back as a staged day the user never chose.
    @Test
    func openingStagesTheCommittedEndOnlyWhileItIsStillReachable() {
        #expect(
            DPDateFieldPolicy.openingStagedDay(mode: rangeMode, value: value("2026-08-24"), minimum: nil, maximum: nil)
                == value("2026-08-24")
        )
        #expect(DPDateFieldPolicy.openingStagedDay(mode: rangeMode, value: value("2026-08-19"), minimum: nil, maximum: nil) == nil)
        #expect(DPDateFieldPolicy.openingStagedDay(mode: rangeMode, value: value(""), minimum: nil, maximum: nil) == nil)
        #expect(DPDateFieldPolicy.openingStagedDay(mode: .single, value: value("2026-08-24"), minimum: nil, maximum: nil) == nil)
    }

    // MARK: - Chrome shared with the calendar screen

    @Test
    func theWeekdayHeaderCarriesTheCalendarScreensWeekendColours() {
        #expect(DPDateFieldPolicy.weekdayColor(column: 0) == DPColor.dangerHover)
        #expect(DPDateFieldPolicy.weekdayColor(column: 6) == DPColor.accentHover)
        for column in 1...5 {
            #expect(DPDateFieldPolicy.weekdayColor(column: column) == DPColor.textPrimary)
        }
    }

    // MARK: - Localization

    @Test
    func theFieldSpeaksTheAppLanguage() {
        let english = Locale(identifier: "en")
        let korean = Locale(identifier: "ko")

        #expect(DPDateFieldLocalization.placeholder(locale: english) == "Select date")
        #expect(DPDateFieldLocalization.placeholder(locale: korean) == "날짜 선택")
        #expect(DPDateFieldLocalization.dialogLabel(isRange: false, locale: english) != DPDateFieldLocalization.dialogLabel(isRange: true, locale: english))
        #expect(DPDateFieldLocalization.rangeHint(locale: korean) == "종료 날짜를 선택하세요")
    }

    /// A locked field is not a control, so VoiceOver has to hear the value and the reason in the
    /// one element it meets.
    @Test
    func theLockedRowSpeaksItsDateAndItsReason() {
        let korean = Locale(identifier: "ko")
        let spoken = DPDateFieldLocalization.lockedAccessibilityValue(value("2026-08-20"), locale: korean)

        #expect(spoken.contains(DatePickerGridLogic.fieldLabel(value("2026-08-20"), locale: korean)))
        #expect(spoken.contains("변경할 수 없음"))
        #expect(DPDateFieldLocalization.lockedAccessibilityValue(value(""), locale: korean) == "변경할 수 없음")
    }

    /// Every string the field adds ships in both languages, and the ones the app already has
    /// stay single: a second "Today" or "Cancel" is how two surfaces drift apart.
    @Test
    func newStringsAreTranslatedAndTheSharedOnesAreReused() throws {
        let catalog = try Self.calendarCatalog()

        for key in [
            "datePicker.placeholder",
            "datePicker.dialogLabel",
            "datePicker.goToToday",
            "datePicker.previousMonth",
            "datePicker.nextMonth",
            "datePicker.range.dialogLabel",
            "datePicker.range.hint",
            "datePicker.range.duration.one",
            "datePicker.range.duration.other"
        ] {
            let entry = try #require(catalog[key] as? [String: Any], "Missing \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
            for language in ["en", "ko"] {
                let unit = try #require(
                    (localizations[language] as? [String: Any])?["stringUnit"] as? [String: Any],
                    "Missing \(language) for \(key)"
                )
                #expect(unit["state"] as? String == "translated", "Untranslated \(language) for \(key)")
                #expect((unit["value"] as? String ?? "").isEmpty == false, "Empty \(language) for \(key)")
            }
        }

        for duplicate in [
            "datePicker.today",
            "datePicker.cancel",
            "datePicker.confirm",
            "datePicker.locked",
            "datePicker.range.start",
            "datePicker.range.end"
        ] {
            #expect(catalog[duplicate] == nil, "\(duplicate) duplicates a string the Calendar table already has")
        }

        let source = try Self.componentSource()
        for reused in [
            "calendar.today",
            "calendar.cancel",
            "calendar.ok",
            "calendar.schedule.start",
            "calendar.schedule.end",
            "calendar.schedule.start.locked"
        ] {
            #expect(source.contains(reused), "The field must reuse \(reused)")
        }
    }

    // MARK: - Layout

    /// The collapsed row is the only part of the field the schedule form has budgeted for, and
    /// it budgeted 36 points. It takes the number from the caller so the caller keeps owning
    /// its own `@ScaledMetric`.
    @Test
    func theCollapsedRowHoldsExactlyTheHeightTheCallerReserves() {
        let height = CalendarVisualLogic.scheduleDateRowHeight

        #expect(fittingSize(of: field(rowHeight: height), proposedWidth: 320).height == height)
        #expect(fittingSize(of: field(rowHeight: height, isReadOnly: true), proposedWidth: 320).height == height)
        #expect(fittingSize(of: field(rowHeight: 52), proposedWidth: 320).height == 52)
    }

    /// A control that shares the row — the schedule form's optional time — sits *beside* the
    /// date, so the row is the one reserved height whether it carries one or not. Under the
    /// date it could not: the time's height has to stay reserved even while nothing is there
    /// (adding a time may never move the fields below it), and a reserved empty band is a hole
    /// in the form.
    @Test
    func anAccessorySharesTheRowRatherThanAddingABandUnderIt() {
        let height = CalendarVisualLogic.scheduleDateRowHeight
        let alone = fittingSize(of: field(rowHeight: height), proposedWidth: 315).height
        let accompanied = fittingSize(
            of: field(rowHeight: height) { Color.clear.frame(width: 96, height: height) },
            proposedWidth: 315
        ).height
        let empty = fittingSize(
            of: field(rowHeight: height) { EmptyView() },
            proposedWidth: 315
        ).height

        #expect(alone == height)
        #expect(accompanied == height, "An accessory shares the row instead of adding a second one")
        #expect(empty == height, "An accessory with nothing to show leaves no band behind")
    }

    /// The label column a form row hangs off narrows what is left for the row's control, and
    /// seven columns feel that narrowing seven times over: confined to the column, a cell was 37
    /// points wide in Korean and 29 in English, on a grid whose cells are 36 points tall. The
    /// calendar is not part of the row, so it bleeds back across the label and both languages
    /// get the same, near-square cell.
    @Test
    func theExpandedCalendarTakesTheWholeRowInBothLanguages() {
        // An iPhone 13 mini: a 375-point screen, less `DPModalOverlay`'s 32 and the editor
        // form's own 28 points of horizontal padding.
        let formWidth: CGFloat = 315
        var pitches: [CGFloat] = []

        for identifier in ["ko", "en"] {
            let labelWidth = CalendarVisualLogic.formLabelWidth(locale: Locale(identifier: identifier))
            let bleed = CalendarVisualLogic.formRowContentInset(labelWidth: labelWidth)
            let width = DPDateFieldLayout.expandedWidth(
                containerWidth: formWidth - bleed,
                leadingBleed: bleed
            )

            #expect(width == formWidth, "\(identifier) leaves the calendar short of the row")
            let pitch = DPDateFieldLayout.dayCellWidth(expandedWidth: width)
            #expect(pitch > 42, "\(identifier) cell is \(pitch) points wide")
            pitches.append(pitch)
        }

        #expect(pitches[0] == pitches[1], "The grid cannot be tighter in one language than the other")
        // What confining it to the column cost, and what this must not regress to.
        #expect(
            DPDateFieldLayout.dayCellWidth(
                expandedWidth: formWidth - CalendarVisualLogic.formRowContentInset(labelWidth: 88)
            ) < 30
        )
    }

    /// The confirm is the whole point of the staged range, so expanding has to be able to put it
    /// on screen: the panel scrolls the open row to the top of its body, which only reveals the
    /// footer if the row and its calendar fit inside that body at all.
    @Test
    func theExpandedRangeCalendarFitsTheModalBodyItIsScrolledInto() {
        // An iPhone 13 mini: 812 points, less its safe areas, less `DPModalOverlay`'s 32, and
        // then the day modal's own header and footer.
        let bodyHeight = DPModalPanelSizingPolicy(
            maximumPanelHeight: 812 - 84 - 32,
            minimumBodyHeight: DPSize.minimumTouchTarget,
            dividerCount: 2
        ).bodyHeight(headerHeight: 64, bodyContentHeight: 2_000, footerHeight: 64)
        let openRow = CalendarVisualLogic.scheduleDateRowHeight
            + DPSpacing.small
            + DPDateFieldLayout.expandedHeight(includesFooter: true)

        #expect(openRow <= bodyHeight, "\(openRow) points of open row in \(bodyHeight) of body")
    }

    /// The middle of a span has to be visible, not merely present. `accentSoft` is the tint the
    /// app puts *behind text*, and in dark mode — the mode this app is used in — it is `#1E3A5F`
    /// on the card's `#1F2937`: at 1.2:1 the block between the two ends all but disappears, and
    /// a five-night stay reads as two marks with a gap. The next step of the same family carries
    /// it while still reading as softer than the ends it runs between.
    @Test
    func theMiddleOfASpanCarriesTheBlockInBothThemes() {
        let middle = DPDateFieldPolicy.fill(state: .middle, isSelected: false)

        for style in [UIUserInterfaceStyle.dark, .light] {
            let onCard = Self.contrast(middle, DPColor.backgroundCard, style: style)
            let againstEnds = Self.contrast(middle, DPColor.accent, style: style)
            let dayNumber = Self.contrast(DPColor.textPrimary, middle, style: style)
            let previous = Self.contrast(DPColor.accentSoft, DPColor.backgroundCard, style: style)

            #expect(onCard > previous, "\(style) middle is no clearer than the tint it replaced")
            #expect(againstEnds > 1.5, "\(style) middle sits at \(againstEnds) against its own ends")
            #expect(dayNumber > 4.5, "\(style) middle reads its day number at \(dayNumber)")
        }

        // Dark mode is where the block was lost, so it is where the floor is set. A pale tint on
        // a white card is a different problem — it is separated by hue and by its dark day
        // numbers, so light mode only has to be told apart from the card at all.
        #expect(Self.contrast(middle, DPColor.backgroundCard, style: .dark) > 1.5)
        #expect(Self.contrast(middle, DPColor.backgroundCard, style: .light) > 1.15)
        // What the tint behind text was worth in dark mode, and what this must not go back to.
        #expect(Self.contrast(DPColor.accentSoft, DPColor.backgroundCard, style: .dark) < 1.3)
    }

    /// The month grid never scrolls inside itself, so the whole six-week block has to fit an
    /// iPhone 13 mini with the rest of the form still visible around it.
    @Test
    func theExpandedCalendarFitsAniPhone13Mini() {
        // 375 x 812 points; `DPModalOverlay` hands its panel `height - 32`.
        let miniScreenHeight: CGFloat = 812

        #expect(DPDateFieldLayout.monthGridHeight() < miniScreenHeight * 0.35)
        #expect(DPDateFieldLayout.expandedHeight(includesFooter: false) < miniScreenHeight * 0.45)
        #expect(DPDateFieldLayout.expandedHeight(includesFooter: true) < miniScreenHeight * 0.55)

        let rendered = fittingSize(
            of: field(rowHeight: CalendarVisualLogic.scheduleDateRowHeight, mode: rangeMode, expanded: true),
            proposedWidth: 343
        )
        #expect(rendered.height < miniScreenHeight - 32)
    }

    // MARK: - Source contract

    /// The first consumer already sits inside `fullScreenCover` → `DPModalOverlay` →
    /// `DPModalPanel`. A popover or sheet would add a fourth layer whose backdrop tap closes the
    /// editor rather than the calendar, so the calendar expands in place instead.
    @Test
    func theCalendarExpandsInlineRatherThanPresentingAnotherLayer() throws {
        let source = try Self.componentSource()

        #expect(source.contains("if isExpanded"))
        for presentation in [".popover(", ".sheet(", ".fullScreenCover(", ".presentationDetents(", "DPModalOverlay("] {
            #expect(source.contains(presentation) == false, "The field must not present \(presentation)")
        }
    }

    /// The locked field keeps the editable box — same height, same radius, same font — and says
    /// what it is through state alone. Both states go through one builder, so the shape is shared
    /// by construction and only colour, edge and glyph are left to differ.
    @Test
    func theLockedStateIsTheSameBoxInADifferentState() throws {
        let source = try Self.componentSource()
        let box = try Self.declaration(named: "private func fieldBox(", in: source)
        let locked = try Self.declaration(named: "private var lockedRow: some View", in: source)
        let trigger = try Self.declaration(named: "private var trigger: some View", in: source)

        #expect(box.contains(".frame(height: rowHeight)"), "One box owns the reserved row height")
        #expect(box.contains("cornerRadius: DPRadius.standard"), "One box owns the input radius")
        #expect(box.contains("DPFont.light(size: DPDateFieldLayout.fieldFontSize"), "One box owns the field font")
        #expect(box.contains("Image(systemName: trailingSymbol)"))

        #expect(trigger.contains("fieldBox("), "The editable row is the same box")
        #expect(trigger.contains(#"trailingSymbol: "calendar""#))

        #expect(locked.contains("fieldBox("), "The locked row is the same box")
        #expect(locked.contains("Button") == false, "A locked field opens nothing, so it is not a button")
        #expect(locked.contains(#"trailingSymbol: "lock.fill""#))
        #expect(locked.contains("dash:"), "The locked edge is dashed")
        #expect(locked.contains("DPColor.textMuted"), "The locked text is muted")
        #expect(locked.contains("DPColor.backgroundTertiary"))
        #expect(locked.contains(".accessibilityElement(children: .ignore)"))
        #expect(locked.contains(".accessibilityLabel(fieldName)"))
        #expect(locked.contains(".accessibilityValue(DPDateFieldLocalization.lockedAccessibilityValue("))
    }

    @Test
    func colourAndTypeComeOnlyFromTheDesignTokens() throws {
        let source = try Self.componentSource()

        for literal in ["Color(red:", "Color(hue:", "Color(uiColor:", "Color(.s", "#colorLiteral", "colorScheme"] {
            #expect(source.contains(literal) == false, "The field must not reach past the tokens with \(literal)")
        }
        #expect(source.contains("DPColor."))
        #expect(source.contains("DPFont."))
    }

    /// The house pattern: the base numbers live in a `nonisolated enum` so they can be asserted,
    /// and the view wraps them so they follow the text size.
    @Test
    func theBaseMetricsAreTestableAndScaleWithDynamicType() throws {
        let source = try Self.componentSource()

        #expect(source.contains("nonisolated enum DPDateFieldLayout"))
        #expect(source.contains("@ScaledMetric(relativeTo: .body) private var dayCellHeight: CGFloat = DPDateFieldLayout.dayCellHeight"))
        #expect(source.contains("@ScaledMetric(relativeTo: .caption2) private var weekdayHeaderHeight: CGFloat = DPDateFieldLayout.weekdayHeaderHeight"))
        #expect(source.contains("@ScaledMetric(relativeTo: .caption) private var headerControlSize: CGFloat = DPDateFieldLayout.headerControlSize"))
    }

    @Test
    func previewsCoverBothModesBothThemesAndBothLanguages() throws {
        let source = try Self.componentSource()

        #expect(source.components(separatedBy: "#Preview").count - 1 >= 6)
        #expect(source.contains(".preferredColorScheme(.dark)"))
        #expect(source.contains(#"Locale(identifier: "ko")"#))
        #expect(source.contains(#"Locale(identifier: "en")"#))
        #expect(source.contains("isReadOnly: true"))
        #expect(source.contains("initiallyExpanded: true"))
        // A staged span that straddles a month boundary is the case the block painting is most
        // likely to break in, so one preview has to show it.
        #expect(source.contains(#"anchor: DateOnly(rawValue: "2026-12-30")"#))
    }

    // MARK: - Helpers

    private func field(
        rowHeight: CGFloat,
        mode: DPDateFieldMode = .single,
        isReadOnly: Bool = false,
        expanded: Bool = false
    ) -> some View {
        field(rowHeight: rowHeight, mode: mode, isReadOnly: isReadOnly, expanded: expanded) {
            EmptyView()
        }
    }

    private func field<Accessory: View>(
        rowHeight: CGFloat,
        mode: DPDateFieldMode = .single,
        isReadOnly: Bool = false,
        expanded: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        DPDateField(
            value: .constant(DateOnly(rawValue: "2026-08-24")),
            fieldName: "End",
            rowHeight: rowHeight,
            mode: mode,
            isReadOnly: isReadOnly,
            locale: Locale(identifier: "en"),
            initiallyExpanded: expanded,
            accessory: accessory
        )
    }

    /// The WCAG relative-luminance ratio between two resolved tokens, so a claim about a fill
    /// being visible is a number rather than an impression.
    private static func contrast(
        _ first: Color,
        _ second: Color,
        style: UIUserInterfaceStyle
    ) -> CGFloat {
        let one = luminance(first, style: style)
        let other = luminance(second, style: style)
        return (max(one, other) + 0.05) / (min(one, other) + 0.05)
    }

    private static func luminance(_ color: Color, style: UIUserInterfaceStyle) -> CGFloat {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func fittingSize<V: View>(of view: V, proposedWidth: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: proposedWidth, height: 2_000)
        )
    }

    private static func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func componentSource() throws -> String {
        try String(
            contentsOf: projectRoot().appending(path: "Dutypark/Components/DPDateField.swift"),
            encoding: .utf8
        )
    }

    private static func calendarCatalog() throws -> [String: Any] {
        let data = try Data(
            contentsOf: projectRoot().appending(path: "Dutypark/Features/Calendar/Calendar.xcstrings")
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }

    /// The body of one declaration, so a claim about the locked row cannot be satisfied by the
    /// editable row somewhere else in the file.
    private static func declaration(named header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "Missing \(header)")
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    private ") ?? rest.range(of: "\n}")
        guard let end else { return String(rest) }
        return String(rest[..<end.lowerBound])
    }
}
