import { describe, expect, it } from 'vitest'
import scheduleForm from './ScheduleForm.vue?raw'
import { endFollowingStart } from './ScheduleForm.vue'

describe('ScheduleForm start and end rows', () => {
  it('lays start and end out in one grid so their controls share columns', () => {
    expect(scheduleForm).toContain('class="schedule-form__datetime"')
    expect(scheduleForm).toMatch(/\.schedule-form__datetime\s*\{[\s\S]*?display: grid;/)
    expect(scheduleForm).toMatch(
      /\.schedule-form__datetime\s*\{[\s\S]*?grid-template-columns: var\(--schedule-form-label-width\) minmax\(0, 1fr\) minmax\(0, 1fr\);/
    )
  })

  it('keeps the time native and picks every date with the shared field', () => {
    const timeInputs = scheduleForm.match(/type="time"/g) ?? []
    expect(timeInputs).toHaveLength(2)
    expect(scheduleForm).not.toContain('type="datetime-local"')
    expect(scheduleForm).not.toContain('type="date"')
    expect(scheduleForm).toContain(
      "import DatePickerField from '@/components/common/DatePickerField.vue'"
    )
    // Three: the fixed start of a new schedule, the editable start, and the end.
    expect(scheduleForm.match(/<DatePickerField/g) ?? []).toHaveLength(3)
  })

  it('renders the fixed start date as the same date control, only read-only', () => {
    expect(scheduleForm).toMatch(/<DatePickerField\s+v-if="!isEditMode"[\s\S]*?\n\s+readonly\n/)
    expect(scheduleForm).toContain(':model-value="startDate"')
    expect(scheduleForm).not.toContain('schedule-form__date-static')
  })

  it('marks a broken range on both dates and both times', () => {
    // The field turns `invalid` into aria-invalid itself, which is what paints the warning border.
    expect(scheduleForm.match(/:invalid="isTimeRangeInvalid"/g) ?? []).toHaveLength(2)
    expect(scheduleForm.match(/:aria-invalid="isTimeRangeInvalid"/g) ?? []).toHaveLength(2)
  })

  it('drops the rule that only hid the native date picker button', () => {
    expect(scheduleForm).not.toContain('schedule-form__date--readonly')
    // The only native picker button left to hide is the time field's.
    const pickerIndicators = scheduleForm.match(/[\w-]+::-webkit-calendar-picker-indicator/g) ?? []
    expect(pickerIndicators).toEqual(['schedule-form__time::-webkit-calendar-picker-indicator'])
  })

  it('offers the time as something to add rather than a midnight to correct', () => {
    expect(scheduleForm).toContain("t('duty.schedule.time.add')")
    expect(scheduleForm).toContain("t('duty.schedule.time.remove')")
    expect(scheduleForm).toContain('v-if="startTime !== null"')
    expect(scheduleForm).toContain('v-if="endTime !== null"')
  })

  it('offers no end time button at all until there is a start time to depend on', () => {
    expect(scheduleForm).toContain('v-else-if="startTime !== null"')
    expect(scheduleForm).not.toContain(':disabled="startTime === null"')
    expect(scheduleForm).not.toContain('.schedule-form__time-add:disabled')
  })

  it('gives every row the same label column so the controls all start at one x', () => {
    // The date/time grid and the rows below it are laid out separately, so a single token is what
    // keeps their labels the same width.
    expect(scheduleForm).not.toContain('w-16')
    expect(scheduleForm).toMatch(
      /\.schedule-form__label\s*\{[\s\S]*?width: var\(--schedule-form-label-width\);/
    )
    // Korean labels are all two-character words, so a two-character column wraps the four-character
    // ones into an even block instead of widening every row.
    expect(scheduleForm).toMatch(
      /\.schedule-form:lang\(ko\)\s*\{[\s\S]*?--schedule-form-label-width: 2rem;/
    )
  })

  it('gives the date and the time an equal half of the row', () => {
    // Both halves are filled, so an empty row shows the add-time chip in the same box the time
    // control will occupy and neither row changes shape when a time appears.
    expect(scheduleForm).toMatch(/\.schedule-form__time,\s*\.schedule-form__time-add\s*\{[^}]*grid-column: 1;/)
    expect(scheduleForm).toMatch(/\.schedule-form__time,\s*\.schedule-form__time-add\s*\{[^}]*width: 100%;/)
  })

  it('keeps the Korean date and time on one phone row and stacks the Latin ones', () => {
    // Two characters of label leave both native controls room on a phone once the time field
    // gives up its picker button; a Latin label's column does not, so there the time drops under
    // the date rather than clipping beside it.
    expect(scheduleForm).toMatch(
      /@media \(max-width: 639px\)[\s\S]*?\.schedule-form:lang\(ko\) \.schedule-form__time::-webkit-calendar-picker-indicator\s*\{\s*display: none;/
    )
    expect(scheduleForm).toMatch(
      /\.schedule-form:not\(:lang\(ko\)\) \.schedule-form__datetime\s*\{[\s\S]*?grid-template-columns: var\(--schedule-form-label-width\) minmax\(0, 1fr\);/
    )
    expect(scheduleForm).toMatch(
      /\.schedule-form:not\(:lang\(ko\)\) \.schedule-form__time-slot\s*\{[^}]*grid-column: 2;/
    )
  })
})

describe('ScheduleForm column alignment', () => {
  it('lays every row on the same two column template instead of ad hoc flex rows', () => {
    expect(scheduleForm).toMatch(/\.schedule-form\s*\{[^}]*display: grid;/)
    expect(scheduleForm).toMatch(
      /\.schedule-form__row\s*\{[^}]*grid-template-columns: var\(--schedule-form-label-width\) minmax\(0, 1fr\);/
    )
    // Every row is the shared row grid, so none of them measures its own label column.
    expect(scheduleForm).not.toMatch(/class="flex items-(center|start) gap-2"/)
    expect(scheduleForm).not.toContain('flex-1 min-w-0')
  })

  it('reserves the clear button column so the row keeps its geometry without a time', () => {
    expect(scheduleForm).toMatch(
      /\.schedule-form__time-slot\s*\{[^}]*grid-template-columns: minmax\(0, 1fr\) var\(--schedule-form-time-clear-width\);/
    )
    expect(scheduleForm).toMatch(/\.schedule-form__time-remove\s*\{[^}]*grid-column: 2;/)
  })

  it('measures the row gap and the column gap from one token each', () => {
    expect(scheduleForm).toMatch(/\.schedule-form\s*\{[^}]*gap: var\(--schedule-form-row-gap\);/)
    expect(scheduleForm).toMatch(
      /\.schedule-form__datetime\s*\{[^}]*row-gap: var\(--schedule-form-row-gap\);/
    )
    expect(scheduleForm).toMatch(
      /\.schedule-form__row\s*\{[^}]*column-gap: var\(--schedule-form-column-gap\);/
    )
    expect(scheduleForm).toMatch(
      /\.schedule-form__datetime\s*\{[^}]*column-gap: var\(--schedule-form-column-gap\);/
    )
    // The root grid owns the vertical rhythm now, so the utility spacing is gone.
    expect(scheduleForm).not.toContain('space-y-1.5')
  })

  it('gives every single line control one height so the rows keep an even rhythm', () => {
    // The date control is a multi-root component, which never inherits this file's scope id, so the
    // shared height only reaches it through :deep().
    expect(scheduleForm).toMatch(
      /input\.schedule-form__input,\s*\.schedule-form__time-add,\s*:deep\(\.schedule-form__date\)\s*\{[^}]*min-height: var\(--schedule-form-control-height\);/
    )
  })

  it('keeps the required marker beside its label without widening the label column', () => {
    // A Korean label column is exactly two Hangul characters wide, so a marker that shared the
    // label's box would wrap; it hangs into the column gap instead of moving every control right.
    expect(scheduleForm).toMatch(
      /\.schedule-form__label--required\s*\{[^}]*white-space: nowrap;/
    )
    expect(scheduleForm).toMatch(/\.schedule-form__required\s*\{[^}]*margin-left:/)
    expect(scheduleForm).toContain(
      '>{{ t(\'duty.schedule.fields.title\') }}<span class="schedule-form__required'
    )
  })

  it('drops a top aligned label onto the first line of its control', () => {
    // The control's border and padding push its text down, and the two line boxes differ in
    // height, so the label's own padding has to answer both.
    expect(scheduleForm).toMatch(
      /\.schedule-form__label--top\s*\{[^}]*padding-top: calc\(\s*var\(--schedule-form-control-pad-y\) \+ 1px \+\s*\(var\(--schedule-form-control-line\) - var\(--schedule-form-label-line\)\) \/ 2\s*\);/
    )
    // The padding token, not a utility class, is what keeps the label on the control's first line.
    expect(scheduleForm).not.toContain('schedule-form__label--top text-sm pt-2')
  })
})

describe('ScheduleForm end date range', () => {
  const endField = scheduleForm.match(/<DatePickerField\s+v-model="endDate"[\s\S]*?\/>/)?.[0] ?? ''

  it('anchors the end date picker at the start so an earlier day is never selectable', () => {
    expect(endField).toContain('mode="range"')
    expect(endField).toContain(':range-start="startDate"')
    expect(endField).toContain(':min="startDate"')
  })

  it('leaves the start a plain single date picker', () => {
    // Only the end is a range: the start is one day, and in create mode it does not move at all.
    expect(scheduleForm.match(/mode="range"/g) ?? []).toHaveLength(1)
    expect(scheduleForm.match(/:range-start=/g) ?? []).toHaveLength(1)
  })

  it('renormalises the end through the follow rule from both date setters', () => {
    expect(
      scheduleForm.match(/props\.form\.endDateTime = endFollowingStart\(/g) ?? []
    ).toHaveLength(2)
  })
})

describe('the end following the start', () => {
  it('pulls an end the start has passed up to the start day, keeping its clock', () => {
    expect(endFollowingStart('2026-08-22T09:00', '2026-08-21', '11:00')).toBe('2026-08-22T11:00')
  })

  it('leaves an end that already falls after the start alone', () => {
    expect(endFollowingStart('2026-08-20T09:00', '2026-08-25', '11:00')).toBe('2026-08-25T11:00')
  })

  it('keeps an end without a time without one, so it still means that whole day', () => {
    // The old start would read back as a real end time, which is why the time is passed in
    // rather than read out of the end.
    expect(endFollowingStart('2026-08-25T09:00', '2026-08-19', null)).toBe('2026-08-25T00:00')
    expect(endFollowingStart('2026-08-19T09:00', '2026-08-25', null)).toBe('2026-08-25T00:00')
  })

  it('re-proposes an end time the start has caught up with on the same day', () => {
    expect(endFollowingStart('2026-08-19T14:00', '2026-08-19', '10:00')).toBe('2026-08-19T15:00')
    // Equal to the start is not after it: that is how "no end time" is stored.
    expect(endFollowingStart('2026-08-19T10:00', '2026-08-19', '10:00')).toBe('2026-08-19T11:00')
  })

  it('falls back to the last minute of the day rather than a midnight that means no time', () => {
    expect(endFollowingStart('2026-08-19T23:30', '2026-08-19', '10:00')).toBe('2026-08-19T23:59')
  })
})
