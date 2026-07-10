import type { DutySource } from '@/types'

export function isInheritedDutySource(source: DutySource | null | undefined): boolean {
  return source === 'PATTERN' || source === 'PATTERN_PAUSED'
}

export function dutySourcePatternLabelKey(source: DutySource | null | undefined): string {
  if (source === 'PATTERN') return 'duty.common.currentPattern'
  if (source === 'PATTERN_PAUSED') return 'duty.common.pausedPattern'
  if (source === 'DEFAULT_OFF') return 'duty.common.patternNotSet'
  return 'duty.common.usePattern'
}
