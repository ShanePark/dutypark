import type { DutyCalendarDay } from '@/types'

export interface DutyTypeCountInput {
  id: number | null
  name: string
  color: string | null
}

export interface DutyTypeCount extends DutyTypeCountInput {
  cnt: number
}

export function buildDutyTypeCounts(
  selectableTypes: DutyTypeCountInput[],
  duties: DutyCalendarDay[],
  year: number,
  month: number,
): DutyTypeCount[] {
  if (selectableTypes.length === 0) return []

  const daysInMonth = new Date(year, month, 0).getDate()
  const dutiesByDay = new Map<number, DutyCalendarDay>()
  for (const duty of duties) {
    if (
      duty.year === year &&
      duty.month === month &&
      duty.day >= 1 &&
      duty.day <= daysInMonth
    ) {
      dutiesByDay.set(duty.day, duty)
    }
  }

  const counts = new Map<number, number>()
  const observedUnavailableTypes = new Map<number, DutyTypeCountInput>()
  const selectableIds = new Set(
    selectableTypes.flatMap((type) => type.id === null ? [] : [type.id]),
  )
  let workingDays = 0

  for (const duty of dutiesByDay.values()) {
    if (duty.dutyTypeId === null || !duty.dutyType) continue

    workingDays++
    counts.set(duty.dutyTypeId, (counts.get(duty.dutyTypeId) ?? 0) + 1)
    if (!selectableIds.has(duty.dutyTypeId)) {
      observedUnavailableTypes.set(duty.dutyTypeId, {
        id: duty.dutyTypeId,
        name: duty.dutyType,
        color: duty.dutyColor,
      })
    }
  }

  const selectableCounts = selectableTypes.map((type) => ({
    ...type,
    cnt: type.id === null
      ? daysInMonth - workingDays
      : (counts.get(type.id) ?? 0),
  }))
  const unavailableCounts = [...observedUnavailableTypes.values()].map((type) => ({
    ...type,
    cnt: counts.get(type.id as number) ?? 0,
  }))

  return [...selectableCounts, ...unavailableCounts]
}
