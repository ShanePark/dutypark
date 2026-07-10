import type { DutyPatternWeekday, MyDutyPatternDto } from '@/types'

export const DUTY_PATTERN_WEEKDAYS: DutyPatternWeekday[] = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
]

export const DEFAULT_DUTY_PATTERN_WEEKDAYS: DutyPatternWeekday[] =
  DUTY_PATTERN_WEEKDAYS.slice(0, 5)

export interface DutyPatternFormState {
  selectedWeekdays: DutyPatternWeekday[]
  holidayOff: boolean
}

export function createDutyPatternFormState(data: MyDutyPatternDto): DutyPatternFormState {
  return {
    selectedWeekdays: data.pattern
      ? [...data.pattern.weekdays]
      : [...DEFAULT_DUTY_PATTERN_WEEKDAYS],
    holidayOff: data.pattern?.holidayOff ?? true,
  }
}

export function toggleDutyPatternWeekday(
  selectedWeekdays: DutyPatternWeekday[],
  day: DutyPatternWeekday,
): DutyPatternWeekday[] {
  if (selectedWeekdays.includes(day)) {
    return selectedWeekdays.filter((item) => item !== day)
  }

  return DUTY_PATTERN_WEEKDAYS.filter(
    (item) => item === day || selectedWeekdays.includes(item),
  )
}
