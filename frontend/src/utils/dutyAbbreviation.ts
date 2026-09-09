/// <reference lib="es2022.intl" />

interface DutyTypeLabelInput {
  name: string
  abbreviation?: string | null
  shortName?: string | null
}

interface DutyLabelInput {
  dutyType?: string | null
  dutyAbbreviation?: string | null
}

const segmenter = typeof Intl.Segmenter === 'function'
  ? new Intl.Segmenter(undefined, { granularity: 'grapheme' })
  : null

const dutyAbbreviationPattern = /^[A-Za-z\uAC00-\uD7A3]{1,3}$/u

/** Trim an explicit override without silently dropping invalid input or changing its case. */
export function normalizeDutyAbbreviation(value: string | null | undefined): string {
  return value?.trim() ?? ''
}

/** Empty means automatic; otherwise one to three ASCII letters or complete Hangul syllables are valid. */
export function isValidDutyAbbreviation(value: string | null | undefined): boolean {
  const normalized = normalizeDutyAbbreviation(value)
  return normalized === '' || dutyAbbreviationPattern.test(normalized)
}

/** An empty override means automatic; never persist the inferred first character. */
export function dutyAbbreviation(name: string | null | undefined, abbreviation?: string | null): string {
  const override = normalizeDutyAbbreviation(abbreviation)
  if (override && isValidDutyAbbreviation(override)) return override
  const fullName = name?.trim() ?? ''
  return segmenter
    ? segmenter.segment(fullName)[Symbol.iterator]().next().value?.segment ?? ''
    : Array.from(fullName)[0] ?? ''
}

/** Ownership, not permission to edit somebody else's calendar, selects compact labels. */
export function dutyTypeLabel(type: DutyTypeLabelInput, isMyCalendar: boolean): string {
  if (!isMyCalendar) return type.name
  return type.shortName?.trim() || dutyAbbreviation(type.name, type.abbreviation)
}

export function dutyLabel(duty: DutyLabelInput, isMyCalendar: boolean): string {
  if (!isMyCalendar) return duty.dutyType ?? ''
  return dutyAbbreviation(duty.dutyType, duty.dutyAbbreviation)
}
