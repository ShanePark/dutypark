/**
 * Extract date part from ISO datetime string (YYYY-MM-DD)
 */
export function extractDatePart(dateTimeStr: string): string {
  return dateTimeStr.split('T')[0] ?? dateTimeStr
}

/**
 * Format datetime to ISO-like format (YYYY-MM-DD HH:mm)
 */
export function formatDateTime(dateTimeStr: string): string {
  const date = new Date(dateTimeStr)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}`
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
    const endTime = `${String(endDate.getHours()).padStart(2, '0')}:${String(endDate.getMinutes()).padStart(2, '0')}`
    if (endTime === '00:00') {
      return startStr
    }
    return `${startStr} ~ ${endTime}`
  }

  return `${startStr} ~ ${formatDateTime(end)}`
}

/**
 * Format date in Korean style (YYYY년 M월 D일)
 * Optionally includes time if the input contains time information
 */
export function formatDateKorean(dateStr: string): string {
  // Date-only format (YYYY-MM-DD) should not show time
  // This avoids timezone issues where UTC midnight becomes 09:00 in KST
  if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    const [year, month, day] = dateStr.split('-').map(Number)
    return `${year}년 ${month}월 ${day}일`
  }

  const date = new Date(dateStr)
  const year = date.getFullYear()
  const month = date.getMonth() + 1
  const day = date.getDate()
  const hours = date.getHours()
  const minutes = date.getMinutes()

  if (hours === 0 && minutes === 0) {
    return `${year}년 ${month}월 ${day}일`
  }
  return `${year}년 ${month}월 ${day}일 ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}
