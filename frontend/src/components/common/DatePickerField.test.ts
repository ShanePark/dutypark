import { describe, expect, it } from 'vitest'
import datePickerField from './DatePickerField.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

const script = datePickerField.slice(0, datePickerField.indexOf('<template>'))
const template = datePickerField.slice(
  datePickerField.indexOf('<template>'),
  datePickerField.indexOf('<style'),
)
const style = datePickerField.slice(datePickerField.indexOf('<style'))

describe('DatePickerField public API', () => {
  it('takes exactly the contracted props', () => {
    for (const prop of [
      'modelValue: string',
      "mode?: 'single' | 'range'",
      'rangeStart?: string',
      'min?: string',
      'max?: string',
      'disabled?: boolean',
      'readonly?: boolean',
      'invalid?: boolean',
      'ariaLabel?: string',
      'placeholder?: string',
    ]) {
      expect(script, `missing prop ${prop}`).toContain(prop)
    }
  })

  it('emits the model update as an ISO string and nothing else', () => {
    expect(script).toContain("'update:modelValue': [value: string]")
    // The only emitted value is `iso`, which comes from the grid and is ISO end to end.
    expect(script.match(/emit\('update:modelValue',[^)]*\)/g)).toEqual([
      "emit('update:modelValue', iso)",
    ])
  })
})

describe('DatePickerField trigger', () => {
  it('is a plain button so it drops in where an input type=date sat', () => {
    expect(template).toMatch(/<button\s+ref="triggerRef"\s+type="button"/)
    expect(template.indexOf('<button\n    ref="triggerRef"')).toBeLessThan(
      template.indexOf('<Teleport'),
    )
  })

  it('wears the app form control look and fills its parent', () => {
    expect(template).toContain('class="date-picker-field form-control"')
    expect(style).toMatch(/\.date-picker-field\s*\{[^}]*width: 100%;/)
  })

  it('gives the whole date up its calendar icon rather than the icon its ellipsis', () => {
    // A Korean date needs ~102px but the schedule modal's half-row column leaves ~86px once the
    // icon and its gap are paid for. The query is on the field, not the window, because the same
    // field is roomy full-width on the very same phone.
    expect(style).toMatch(/\.date-picker-field\s*\{[^}]*container-type: inline-size;/)
    expect(style).toMatch(
      /@container \(max-width: 9rem\)\s*\{\s*\.date-picker-field__icon--calendar\s*\{\s*display: none;/,
    )
    // The lock is what says "you cannot change this", so it is not part of that trade.
    expect(style).not.toMatch(
      /@container[\s\S]*?\.date-picker-field__icon--lock\s*\{\s*display: none;/,
    )
  })

  it('lands attribute and class fallthrough on the button itself', () => {
    // Two root nodes (button + Teleport) switch automatic fallthrough off, so it has to be
    // forwarded by hand or the call sites lose their layout classes.
    expect(script).toContain('defineOptions({ inheritAttrs: false })')
    expect(template).toContain('v-bind="$attrs"')
    // Last binding on the element, so a caller's attribute wins over the default.
    expect(template).toMatch(/v-bind="\$attrs"\s*>/)
  })

  it('renders the warning border through aria-invalid, like the schedule form inputs', () => {
    expect(template).toContain(":aria-invalid=\"invalid ? 'true' : undefined\"")
    // .form-control[aria-invalid="true"] already paints border-color: var(--dp-warning).
    expect(style).not.toContain('--dp-warning')
  })

  it('opens nothing when disabled or read-only', () => {
    expect(script).toContain('const canOpen = computed(() => !props.disabled && !props.readonly)')
    expect(script).toContain('if (!canOpen.value || isOpen.value) return')
    expect(template).toContain(':disabled="disabled"')
    expect(template).toContain(":aria-readonly=\"readonly ? 'true' : undefined\"")
  })

  it('shows the placeholder only while there is no value', () => {
    expect(template).toContain('hasValue ? displayValue : placeholderText')
    expect(script).toContain("props.placeholder ?? t('common.datePicker.placeholder')")
  })
})

describe('DatePickerField popover', () => {
  it('escapes the modal by teleporting to the body and positioning against the viewport', () => {
    // A modal body scrolls and clips; an absolutely positioned popover inside it would be cut off.
    expect(template).toContain('<Teleport to="body">')
    expect(style).toMatch(/\.date-picker-popover\s*\{[\s\S]*?position: fixed;/)
    expect(style).toMatch(/\.date-picker-popover\s*\{[\s\S]*?z-index: 9999;/)
  })

  it('clamps and flips itself through the tested positioning helper', () => {
    expect(script).toContain('resolvePopoverPosition(')
    expect(script).toContain('{ width: window.innerWidth, height: window.innerHeight }')
    expect(script).toContain('popoverMaxWidth.value = maxPopoverWidth(window.innerWidth)')
    expect(style).toMatch(/\.date-picker-popover\s*\{[\s\S]*?max-height: calc\(100dvh - 1rem\);/)
  })

  it('stays anchored while the page or the modal body scrolls', () => {
    expect(script).toContain("window.addEventListener('resize', updatePosition)")
    expect(script).toContain("window.addEventListener('scroll', updatePosition, true)")
    expect(script).toContain("window.removeEventListener('scroll', updatePosition, true)")
  })

  it('closes on Escape, on an outside click, and once a day is picked', () => {
    // The shared escape stack means the picker closes before the modal that contains it.
    expect(script).toContain("useEscapeKey(isOpen, () => close({ restoreFocus: true }))")
    expect(script).toContain("document.addEventListener('pointerdown', handlePointerDownOutside, true)")
    expect(script).toContain(
      'if (triggerRef.value?.contains(target) || popoverRef.value?.contains(target)) return',
    )
    expect(script).toMatch(/emit\('update:modelValue', iso\)\s*\n\s*close\(\{ restoreFocus: true \}\)/)
  })

  it('drops every listener when it closes and when it unmounts', () => {
    expect(script).toContain('onBeforeUnmount(stopListening)')
    expect(script).toMatch(/watch\(isOpen[\s\S]*?stopListening\(\)/)
  })

  it('offers month navigation, a month title, a weekday row, and a today action', () => {
    expect(template).toContain("t('common.calendar.previousMonth')")
    expect(template).toContain("t('common.calendar.nextMonth')")
    expect(template).toContain('{{ monthLabel }}')
    expect(template).toContain('v-for="(label, index) in weekdayLabels"')
    expect(template).toContain("t('common.datePicker.today')")
    expect(template).toContain('@click="goToToday"')
  })

  it('marks today and the selected day, and blocks days outside min and max', () => {
    expect(template).toContain("'date-picker-day--today': cell.isToday")
    expect(template).toContain("'date-picker-day--selected': cell.isSelected")
    expect(template).toContain(':disabled="cell.isDisabled"')
    expect(script).toContain('isDisabled: isDateDisabled(cell.date, effectiveMin.value, props.max)')
    expect(script).toContain('if (isDateDisabled(iso, effectiveMin.value, props.max)) return')
  })

  it('greys out a month arrow that would only reach unreachable days', () => {
    expect(template).toContain(':disabled="!canGoPrevious"')
    expect(template).toContain(':disabled="!canGoNext"')
  })
})

describe('DatePickerField keyboard and ARIA', () => {
  it('wires the field to the dialog it opens', () => {
    expect(template).toContain(":aria-haspopup=\"canOpen ? 'dialog' : undefined\"")
    expect(template).toContain(':aria-expanded="canOpen ? isOpen : undefined"')
    expect(template).toContain(':aria-label="ariaLabel"')
    expect(template).toContain('role="dialog"')
    expect(template).toContain(':aria-label="dialogLabel"')
    expect(script).toContain(
      "t(isRange.value ? 'common.datePicker.rangeDialogLabel' : 'common.datePicker.dialogLabel')",
    )
  })

  it('exposes the month as a grid with one tabbable day', () => {
    expect(template).toContain('role="grid"')
    expect(template).toContain('role="row"')
    expect(template).toContain('role="columnheader"')
    expect(template).toContain('role="gridcell"')
    expect(template).toContain(':tabindex="cell.date === rovingDate ? 0 : -1"')
    expect(template).toContain(':aria-selected="cell.isSelected"')
    expect(template).toContain(":aria-current=\"cell.isToday ? 'date' : undefined\"")
    // A bare day number tells a screen reader nothing about which month it belongs to.
    expect(template).toContain(':aria-label="cell.label"')
  })

  it('moves the focused day with the arrow keys and pages months', () => {
    for (const key of ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown']) {
      expect(script, `missing key handling for ${key}`).toContain(`${key}:`)
    }
    expect(template).toContain('@keydown="handleGridKeydown"')
    expect(script).toContain('event.preventDefault()')
  })

  it('selects with the day button itself, so Enter and Space need no extra handler', () => {
    expect(template).toMatch(/type="button"[\s\S]{0,900}?@click="selectDate\(cell\.date\)"/)
  })

  it('hands focus into the grid on open and back to the field on close', () => {
    expect(script).toContain('await focusRovingDay()')
    expect(script).toContain('triggerRef.value?.focus()')
  })
})

describe('DatePickerField range mode', () => {
  it('is opt-in and needs a real anchor, so every existing single-date call site is untouched', () => {
    expect(script).toContain("mode: 'single',")
    expect(script).toContain(
      "props.mode === 'range' && isIsoDate(props.rangeStart) ? props.rangeStart : ''",
    )
    expect(script).toContain("const isRange = computed(() => rangeAnchor.value !== '')")
  })

  it('folds the anchor into a single lower bound the whole popover obeys', () => {
    expect(script).toContain(
      'isRange.value ? resolveRangeMin(props.min, rangeAnchor.value) : props.min',
    )
    // Disabling, keyboard movement, month paging and the previous arrow all read the same bound,
    // so a day before the anchor cannot be reached by any of them.
    for (const use of [
      'isDisabled: isDateDisabled(cell.date, effectiveMin.value, props.max)',
      'if (isDateDisabled(iso, effectiveMin.value, props.max)) return',
      'addDaysIso(visibleMonthStart.value, -1) >= effectiveMin.value',
    ]) {
      expect(script, `missing bound use ${use}`).toContain(use)
    }
    expect(script).toMatch(/function moveFocusTo[\s\S]*?isDateDisabled\(iso, effectiveMin\.value, props\.max\)/)
    expect(script).toMatch(/function shiftMonth[\s\S]*?clampIsoToRange\([\s\S]*?effectiveMin\.value/)
  })

  it('keeps a disabled day out of the tab order even when it is the focused one', () => {
    // Roving tabindex hands the single tab stop to a day that can actually take focus.
    expect(script).toContain(
      'cells.some((cell) => cell.date === focusedDate.value && !cell.isDisabled)',
    )
    expect(template).toContain(':tabindex="cell.date === rovingDate ? 0 : -1"')
  })

  it('stages a click instead of emitting it, and emits only from confirm', () => {
    expect(script).toMatch(
      /function selectDate[\s\S]*?if \(isRange\.value\) \{\s*pendingDate\.value = iso[\s\S]*?return\s*\}\s*commit\(iso\)/,
    )
    expect(script).toMatch(/function confirmRange[\s\S]*?commit\(pendingDate\.value\)/)
    // One emit in the file, reached from commit() alone.
    expect(script.match(/emit\('update:modelValue',[^)]*\)/g)).toEqual([
      "emit('update:modelValue', iso)",
    ])
  })

  it('discards the staged day on cancel, Escape and an outside click, without emitting', () => {
    // close() is the single discard path, and all three routes go through it.
    expect(script).toMatch(/function close\([\s\S]*?pendingDate\.value = ''/)
    expect(script).toContain("useEscapeKey(isOpen, () => close({ restoreFocus: true }))")
    expect(script).toMatch(/function handlePointerDownOutside[\s\S]*?close\(\)/)
    expect(template).toContain('@click="close({ restoreFocus: true })"')
    expect(template).toContain("t('common.datePicker.cancel')")
  })

  it('keeps confirm disabled until a day has been staged', () => {
    expect(script).toContain(
      "const canConfirm = computed(() => isRange.value && pendingDate.value !== '')",
    )
    expect(script).toMatch(/function confirmRange\(\) \{\s*if \(!canConfirm\.value\) return/)
    expect(template).toContain(':disabled="!canConfirm"')
    expect(template).toContain("t('common.datePicker.confirm')")
  })

  it('previews the span on hover and on keyboard focus, both ahead of any click', () => {
    expect(template).toContain('hoveredDate = cell.isDisabled')
    expect(template).toContain('@focus="handleDayFocus(cell.date)"')
    expect(template).toContain('@mouseleave="hoveredDate = \'\'"')
    expect(script).toMatch(
      /const previewEnd = computed\(\(\) => \{[\s\S]*?hoveredDate\.value[\s\S]*?isFocusInGrid\.value \? focusedDate\.value : pendingDate\.value/,
    )
    // Arrow keys move focus between days, which fires focusout; clearing on those would make the
    // span blink on every keypress.
    expect(script).toMatch(
      /function handleGridFocusOut[\s\S]*?grid\.contains\(next\)\) return/,
    )
    expect(template).toContain('@focusout="handleGridFocusOut"')
  })

  it('refuses to preview out of a day the grid has disabled', () => {
    // Chrome suppresses click on a disabled button but still fires mouseenter, so an unguarded
    // binding lets a sweep across the days before the anchor paint a span running backwards out
    // of it — over the very days that are supposed to be unreachable.
    expect(template).toContain(`@mouseenter="hoveredDate = cell.isDisabled ? '' : cell.date"`)
  })

  it('paints the preview as one continuous block through the tested state helper', () => {
    expect(script).toContain(
      'resolveRangeDayState(cell.date, rangeAnchor.value, previewEnd.value)',
    )
    expect(script).toContain("`date-picker-day--range-${rangeState}`")
    expect(template).toContain('cell.rangeClass')
    // Ends rounded on their outer corner only, so the fill between them has no seams.
    expect(style).toMatch(/\.date-picker-day--range-start\s*\{[^}]*border-radius: 0\.5rem 0 0 0\.5rem;/)
    expect(style).toMatch(/\.date-picker-day--range-end\s*\{[^}]*border-radius: 0 0\.5rem 0\.5rem 0;/)
    expect(style).toMatch(/\.date-picker-day--range-middle[^{]*\{[^}]*border-radius: 0;/)
    expect(style).toMatch(/\.date-picker-day--range-middle[^{]*\{[^}]*background-color: var\(--dp-accent-bg\);/)
    // Hover would otherwise win on specificity and punch a hole in the bar.
    expect(style).toContain('.date-picker-day--range-middle:hover:not(:disabled)')
  })

  it('reads back the exact span confirm would commit, not the one under the cursor', () => {
    expect(script).toMatch(/const pendingRange = computed[\s\S]*?countDaysInclusive\(rangeAnchor\.value, pendingDate\.value\)/)
    for (const key of ['rangeStart', 'rangeEnd', 'rangeDuration', 'rangeHint'] as const) {
      expect(template, `missing ${key} in the summary`).toContain(`common.datePicker.${key}`)
    }
    expect(template).toContain('{{ anchorLabel }}')
    expect(template).toContain('aria-live="polite"')
  })

  it('leaves single-date mode exactly as it was: click applies, no footer at all', () => {
    expect(script).toMatch(/function selectDate[\s\S]*?commit\(iso\)\s*\}/)
    expect(template).toContain('<div v-if="isRange" class="date-picker-popover__footer">')
    // The range fill must not bleed into the single-date selected style.
    expect(template).toContain("'date-picker-day--selected': cell.isSelected && !isRange")
  })

  it('drops a staged day that an anchor moving under the open popover would invalidate', () => {
    expect(script).toMatch(
      /watch\(effectiveMin[\s\S]*?isDateDisabled\(pendingDate\.value, effectiveMin\.value, props\.max\)[\s\S]*?pendingDate\.value = ''/,
    )
  })
})

describe('DatePickerField today control', () => {
  it('sits in the calendar header next to the month arrows, not in the footer', () => {
    const header = template.slice(
      template.indexOf('date-picker-popover__header'),
      template.indexOf('date-picker-popover__grid'),
    )
    expect(header).toContain("t('common.datePicker.today')")
    expect(header).toContain("t('common.calendar.previousMonth')")
    expect(header).toContain("t('common.calendar.nextMonth')")
    // The footer only ever holds the range actions now.
    const footer = template.slice(template.indexOf('date-picker-popover__footer'))
    expect(footer).not.toContain("t('common.datePicker.today')")
  })

  it('navigates in both modes and can never commit a value', () => {
    expect(script).toMatch(
      /function goToToday\(\) \{[\s\S]*?visibleMonth\.value = toMonth\(todayIso\.value\)[\s\S]*?focusedDate\.value = todayIso\.value[\s\S]*?focusRovingDay\(\)/,
    )
    // No branch on isRange, and no call into the commit path.
    const body = script.slice(script.indexOf('function goToToday'))
    const goToTodayBody = body.slice(0, body.indexOf('\n}'))
    expect(goToTodayBody).not.toContain('isRange')
    expect(goToTodayBody).not.toContain('commit')
    expect(goToTodayBody).not.toContain('selectDate')
  })

  it('greys itself out only when today is genuinely out of bounds', () => {
    expect(script).toContain(
      'const canGoToToday = computed(() => !isDateDisabled(todayIso.value, effectiveMin.value, props.max))',
    )
    expect(template).toContain(':disabled="!canGoToToday"')
  })

  it('is a labelled, keyboard reachable button that reads as an action', () => {
    expect(template).toContain(":aria-label=\"t('common.datePicker.goToToday')\"")
    expect(style).toMatch(/\.date-picker-popover__today\s*\{[^}]*background-color: var\(--dp-accent-bg\);/)
    expect(style).toContain('.date-picker-popover__today:focus-visible')
    // No tabindex escape hatch anywhere in the popover chrome.
    expect(template).not.toContain('tabindex="-1"')
  })

  it('still marks today in the grid the conventional way', () => {
    expect(template).toContain("'date-picker-day--today': cell.isToday")
    expect(template).toContain(":aria-current=\"cell.isToday ? 'date' : undefined\"")
    expect(style).toMatch(/\.date-picker-day--today\s*\{[^}]*border-color: var\(--dp-accent-border\);/)
  })
})

describe('DatePickerField read-only presentation', () => {
  it('shows a lock instead of the calendar, and keeps it on the narrowest row', () => {
    expect(template).toContain('<Lock v-if="readonly"')
    expect(template).toContain('<Calendar v-else')
    expect(template).toContain("t('common.datePicker.locked')")
  })

  it('carries the state on more than a background, which the dark theme flattens', () => {
    // --dp-bg-tertiary and --dp-bg-input are both #374151 in the dark theme, so a background
    // swap alone leaves a read-only field pixel-identical to an editable one there.
    const readonly = style.slice(
      style.indexOf('.date-picker-field--readonly {'),
      style.indexOf('.date-picker-field--empty'),
    )
    expect(readonly).toContain('border-style: dashed;')
    expect(readonly).toContain('color: var(--dp-text-muted);')
    expect(readonly).toContain('cursor: default;')
    expect(style).toContain('.date-picker-field--readonly .date-picker-field__value')
  })

  it('drops every press cue: no hover, no accent focus ring, no button chrome', () => {
    expect(style).toMatch(
      /\.date-picker-field--readonly:hover,\s*\.date-picker-field--readonly:focus,\s*\.date-picker-field--readonly:active\s*\{[^}]*box-shadow: none;/,
    )
    expect(style).toMatch(
      /\.date-picker-field--readonly:hover[\s\S]*?\{[^}]*background-color: var\(--dp-bg-tertiary\);/,
    )
    // Reachable and visible to a keyboard user, but muted rather than the accent ring an
    // editable field shows.
    expect(style).toMatch(
      /\.date-picker-field--readonly:focus-visible\s*\{[^}]*outline: 2px solid var\(--dp-text-muted\);/,
    )
    expect(template).toContain(":aria-readonly=\"readonly ? 'true' : undefined\"")
    // canOpen is false while read-only, so the popup hint never renders.
    expect(template).toContain(":aria-haspopup=\"canOpen ? 'dialog' : undefined\"")
  })

  it('differentiates the state without moving the geometry', () => {
    // Every declaration the read-only state adds, and nothing else.
    const readonly = [...style.matchAll(/([^{}]*--readonly[^{}]*)\{([^}]*)\}/g)]
      .map((match) => match[2])
      .join('\n')
    expect(readonly).not.toBe('')
    // Anything that would change the box would break the row the field is aligned in.
    for (const property of ['padding', 'width', 'height', 'font-size', 'border-width', 'display']) {
      expect(readonly, `read-only must not set ${property}`).not.toMatch(
        new RegExp(`(^|[;{\\s])${property}:`),
      )
    }
  })
})

describe('DatePickerField theming and locale', () => {
  it('colors itself only from the shared design tokens', () => {
    const declaredColors = style.match(/#[0-9a-fA-F]{3,8}\b|\brgba?\(/g) ?? []
    expect(declaredColors).toEqual([])
    expect(style).toContain('var(--dp-bg-card)')
    expect(style).toContain('var(--dp-border-primary)')
    expect(style).toContain('var(--dp-accent)')
  })

  it('swaps the dropdown shadow for the dark-theme one', () => {
    expect(style).toContain('box-shadow: var(--dp-shadow-dropdown);')
    expect(style).toMatch(
      /:global\(\.dark \.date-picker-popover\)\s*\{[^}]*var\(--dp-shadow-dropdown-dark\)/,
    )
  })

  it('keeps the dark selector whole inside one :global()', () => {
    // `:global(.dark) .date-picker-popover` compiles to a bare `.dark { box-shadow: ... }`:
    // the descendant is dropped, the popover keeps the light shadow, and <html> gets one.
    const declarations = style.replace(/\/\*[\s\S]*?\*\//g, '')
    // Anything other than the opening brace after `:global(...)` is a dropped descendant.
    expect(declarations).not.toMatch(/:global\([^)]*\)\s*[^{\s]/)
  })

  it('drives every piece of date text off the active i18n locale', () => {
    expect(script).toContain('const { t, locale } = useI18n()')
    for (const call of [
      'formatFieldValue(props.modelValue, locale.value)',
      'buildWeekdayLabels(locale.value)',
      'formatDayLabel(cell.date, locale.value)',
    ]) {
      expect(script, `missing locale-driven ${call}`).toContain(call)
    }
    expect(script).toContain('formatMonthLabel(visibleMonth.value.year, visibleMonth.value.month, locale.value)')
  })

  it('adds no npm dependency beyond what the app already ships', () => {
    const imports = [...script.matchAll(/from '([^']+)'/g)].map((match) => match[1])
    expect(imports.sort()).toEqual([
      './datePickerGrid',
      '@/composables/useEscapeKey',
      '@/utils/date',
      'lucide-vue-next',
      'vue',
      'vue-i18n',
    ])
  })
})

describe('DatePickerField messages', () => {
  it('ships the same date picker keys in both locales', () => {
    expect(Object.keys(ko.common.datePicker).sort()).toEqual(
      Object.keys(en.common.datePicker).sort(),
    )
    expect(Object.keys(ko.common.datePicker).sort()).toEqual([
      'cancel',
      'confirm',
      'dialogLabel',
      'goToToday',
      'locked',
      'placeholder',
      'rangeDialogLabel',
      'rangeDuration',
      'rangeEnd',
      'rangeHint',
      'rangeStart',
      'today',
    ])
  })

  it('translates them rather than repeating the Korean copy', () => {
    for (const key of Object.keys(ko.common.datePicker) as (keyof typeof ko.common.datePicker)[]) {
      expect(en.common.datePicker[key]).not.toBe(ko.common.datePicker[key])
      expect(en.common.datePicker[key]).toMatch(/^[\x20-\x7e]+$/)
    }
  })
})
