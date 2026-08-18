export function canEditCalendarSchedule(canEditCalendar: boolean, isTagged: boolean): boolean {
  return canEditCalendar && !isTagged
}

export function isOwnedCalendarSchedule(isMyCalendar: boolean, isTagged: boolean): boolean {
  return isMyCalendar && !isTagged
}

export function canReportCalendarSchedule(
  isLoggedIn: boolean,
  viewerMemberId: number | null,
  ownerMemberId: number | null,
): boolean {
  return isLoggedIn && viewerMemberId !== null && ownerMemberId !== null && viewerMemberId !== ownerMemberId
}
