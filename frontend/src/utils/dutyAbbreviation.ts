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

/** An empty override means automatic; never persist the inferred first character. */
export function dutyAbbreviation(name: string | null | undefined, abbreviation?: string | null): string {
  const override = abbreviation?.trim()
  if (override) return override
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
