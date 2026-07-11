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
  assignments: DutyPatternAssignment[]
  holidayOff: boolean
}

export interface DutyPatternAssignment {
  weekday: DutyPatternWeekday
  dutyTypeId: number
}

export function createDutyPatternFormState(data: MyDutyPatternDto): DutyPatternFormState {
  return {
    assignments: data.pattern
      ? data.pattern.days.map((day) => ({
          weekday: day.weekday,
          dutyTypeId: day.dutyType.id,
        }))
      : data.dutyTypes[0]
        ? DEFAULT_DUTY_PATTERN_WEEKDAYS.map((weekday) => ({
            weekday,
            dutyTypeId: data.dutyTypes[0]!.id,
          }))
        : [],
    holidayOff: data.pattern?.holidayOff ?? true,
  }
}

export function toggleDutyPatternWeekday(
  assignments: DutyPatternAssignment[],
  day: DutyPatternWeekday,
  defaultDutyTypeId: number | null,
): DutyPatternAssignment[] {
  if (assignments.some((item) => item.weekday === day)) {
    return assignments.filter((item) => item.weekday !== day)
  }
  if (defaultDutyTypeId === null) return assignments

  const next = [...assignments, { weekday: day, dutyTypeId: defaultDutyTypeId }]
  return DUTY_PATTERN_WEEKDAYS.flatMap((weekday) =>
    next.filter((item) => item.weekday === weekday),
  )
}
