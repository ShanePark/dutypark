export function canEditCalendarSchedule(canEditCalendar: boolean, isTagged: boolean): boolean {
  return canEditCalendar && !isTagged
}

export function isOwnedCalendarSchedule(isMyCalendar: boolean, isTagged: boolean): boolean {
  return isMyCalendar && !isTagged
}
