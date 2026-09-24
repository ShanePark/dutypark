interface CalendarGridDate {
  year: number
  month: number
}

export interface CalendarGridSlice<T> {
  days: T[]
  startIndex: number
}

export function getCalendarGridSlice<T extends CalendarGridDate>(
  days: T[],
  year: number,
  month: number,
): CalendarGridSlice<T> {
  const firstMonthDayIndex = days.findIndex((day) => day.year === year && day.month === month)
  if (firstMonthDayIndex === -1) return { days, startIndex: 0 }

  let lastMonthDayIndex = firstMonthDayIndex
  for (let index = firstMonthDayIndex + 1; index < days.length; index++) {
    if (days[index].year === year && days[index].month === month) {
      lastMonthDayIndex = index
    }
  }

  const startIndex = Math.floor(firstMonthDayIndex / 7) * 7
  const endIndex = Math.min(days.length, Math.floor(lastMonthDayIndex / 7) * 7 + 7)

  return { days: days.slice(startIndex, endIndex), startIndex }
}
