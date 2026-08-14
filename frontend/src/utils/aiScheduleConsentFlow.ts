import type { AiScheduleParsingConsentDto } from '@/api/consent'

export type AiScheduleConsentAction = 'request-ai' | 'prompt' | 'without-ai'

export function canReenableAiScheduleConsentWithoutPrompt(
  consent: AiScheduleParsingConsentDto | null,
): boolean {
  return consent?.previouslyConsentedToCurrentPolicy === true
}

export function isAiTimeParsingCandidate(startDateTime: string, endDateTime: string): boolean {
  return isMidnight(startDateTime) && isMidnight(endDateTime)
}

export function getAiScheduleConsentAction(
  consent: AiScheduleParsingConsentDto,
): AiScheduleConsentAction {
  if (consent.consented && !consent.needsRenewal) return 'request-ai'
  if (consent.needsRenewal || (!consent.consented && consent.revokedAt === null)) return 'prompt'
  return 'without-ai'
}

function isMidnight(dateTime: string): boolean {
  return /T00:00(?::00(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?$/.test(dateTime)
}
