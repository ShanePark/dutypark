/**
 * Whether tapping a day is worth anything.
 *
 * The day detail lists schedules and nothing else: the duty is already told by the
 * colour of the cell, and holidays, D-Days and to-dos are drawn in the cell itself.
 * So a reader who cannot write opens an empty modal on a day that holds no schedule,
 * and the day stays shut instead. Where I can edit — my own calendar, or one I manage
 * — every day opens, since that is how a schedule reaches an empty one.
 */
export function canOpenCalendarDay(canEdit: boolean, scheduleCount: number): boolean {
  return canEdit || scheduleCount > 0
}
