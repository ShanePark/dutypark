import SwiftUI

/// Sheet-presented year/month picker shared by the Team and Guest public calendars.
///
/// Both screens show the same medium-detent sheet: a year stepper, a 4-column month
/// grid and a "this month" shortcut. Only the localized strings and the accessibility
/// identifiers differ, so they are passed in. Pass `identifierPrefix` to expose the
/// picker to UI tests; screens that are queried by label leave it `nil` so that the
/// month buttons keep matching on their localized titles.
struct DPYearMonthPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    private let selectedYear: Int
    private let selectedMonth: Int
    private let title: Text
    private let previousYearLabel: Text
    private let nextYearLabel: Text
    private let currentMonthTitle: Text
    private let cancelTitle: String
    private let identifierPrefix: String?
    private let onSelect: (Int, Int) -> Void
    private let onCurrentMonth: () -> Void

    init(
        selectedYear: Int,
        selectedMonth: Int,
        title: Text,
        previousYearLabel: Text,
        nextYearLabel: Text,
        currentMonthTitle: Text,
        cancelTitle: String,
        identifierPrefix: String? = nil,
        onSelect: @escaping (Int, Int) -> Void,
        onCurrentMonth: @escaping () -> Void
    ) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.title = title
        self.previousYearLabel = previousYearLabel
        self.nextYearLabel = nextYearLabel
        self.currentMonthTitle = currentMonthTitle
        self.cancelTitle = cancelTitle
        self.identifierPrefix = identifierPrefix
        self.onSelect = onSelect
        self.onCurrentMonth = onCurrentMonth
        _year = State(initialValue: selectedYear)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DPSpacing.medium) {
                yearStepper
                monthGrid

                Button {
                    if isCurrentMonthAlreadySelected {
                        DPHapticCenter.shared.emit(.routine)
                    }
                    onCurrentMonth()
                } label: {
                    currentMonthTitle
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DPSpacing.medium)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        DPHapticCenter.shared.emit(.routine)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .dpIdentifier(identifierPrefix)
    }

    private var yearStepper: some View {
        HStack {
            Button {
                year -= 1
                DPHapticCenter.shared.emit(.selection)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(previousYearLabel)

            Spacer()
            Text(verbatim: String(year)).font(.title3.bold())
            Spacer()

            Button {
                year += 1
                DPHapticCenter.shared.emit(.selection)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(nextYearLabel)
            .dpIdentifier(identifierPrefix.map { "\($0).nextYear" })
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
            ForEach(1...12, id: \.self) { month in
                let isSelected = year == selectedYear && month == selectedMonth
                Button {
                    if isSelected {
                        // There is no committed transition for this choice; the sheet still
                        // closes, so acknowledge that explicit dismissal here.
                        DPHapticCenter.shared.emit(.routine)
                    }
                    onSelect(year, month)
                } label: {
                    Text(verbatim: DPYearMonthPickerLocalization.monthName(month))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                        .background(isSelected ? DPColor.accent : DPColor.backgroundTertiary)
                        .foregroundStyle(isSelected ? DPColor.textOnDark : DPColor.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                }
                .buttonStyle(.plain)
                .dpIdentifier(identifierPrefix.map { "\($0).month.\(month)" })
            }
        }
    }

    private var isCurrentMonthAlreadySelected: Bool {
        let components = CalendarDateSupport.calendar.dateComponents([.year, .month], from: Date())
        return selectedYear == components.year && selectedMonth == components.month
    }
}

nonisolated enum DPYearMonthPickerLocalization {
    /// Month names follow the in-app language instead of the device calendar.
    static func monthName(_ month: Int, locale: Locale = AppLocalization.locale) -> String {
        guard (1...12).contains(month) else { return String(month) }
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.monthSymbols[month - 1]
    }
}

private extension View {
    /// Applies an accessibility identifier only when one is supplied, so screens
    /// without identifiers keep matching UI test queries on their labels.
    @ViewBuilder
    func dpIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
