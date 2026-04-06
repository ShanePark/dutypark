import { getCurrentLocale } from '@/i18n'

/**
 * Extract date part from ISO datetime string (YYYY-MM-DD)
 */
export function extractDatePart(dateTimeStr: string): string {
  return dateTimeStr.split('T')[0] ?? dateTimeStr
}

/**
 * Format a Date as a local YYYY-MM-DD string.
 */
export function formatDateOnly(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * Format a date-only value as YYYY/M/D without UTC drift.
 */
export function formatDateNumeric(dateStr: string): string {
  const date = /^\d{4}-\d{2}-\d{2}$/.test(dateStr)
    ? parseDateOnly(dateStr)
    : new Date(dateStr)

  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
}

/**
 * Parse a YYYY-MM-DD string as a local date to avoid UTC drift.
 */
export function parseDateOnly(dateStr: string): Date {
  const [yearPart = '0', monthPart = '1', dayPart = '1'] = dateStr.split('-')
  const year = Number(yearPart)
  const month = Number(monthPart)
  const day = Number(dayPart)
  return new Date(year, month - 1, day)
}

function getLocale() {
  return getCurrentLocale()
}

function formatWithLocale(date: Date, options: Intl.DateTimeFormatOptions): string {
  return new Intl.DateTimeFormat(getLocale(), options).format(date)
}

/**
 * Format datetime to ISO-like format (YYYY-MM-DD HH:mm)
 */
export function formatDateTime(dateTimeStr: string): string {
  const date = new Date(dateTimeStr)
  return formatWithLocale(date, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}

/**
 * Format date range for display
 * If same day, shows: YYYY-MM-DD HH:mm ~ HH:mm (or just start if end is 00:00)
 * If different days, shows: YYYY-MM-DD HH:mm ~ YYYY-MM-DD HH:mm
 */
export function formatDateRange(start: string, end: string): string {
  const startDate = new Date(start)
  const endDate = new Date(end)

  const startStr = formatDateTime(start)

  if (startDate.toDateString() === endDate.toDateString()) {
    const endTime = formatWithLocale(endDate, {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    })
    if (endTime === '00:00') {
      return startStr
    }
    return `${startStr} ~ ${endTime}`
  }

  return `${startStr} ~ ${formatDateTime(end)}`
}

/**
 * Format a date with the active locale.
 * Optionally includes time if the input contains time information.
 */
export function formatDateKorean(dateStr: string): string {
  // Date-only values should not show time.
  // This avoids timezone drift where UTC midnight becomes local morning time.
  if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    return formatWithLocale(parseDateOnly(dateStr), {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }

  const date = new Date(dateStr)
  const hours = date.getHours()
  const minutes = date.getMinutes()

  if (hours === 0 && minutes === 0) {
    return formatWithLocale(date, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }
  return formatWithLocale(date, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}
