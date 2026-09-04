import { ref } from 'vue'
import { adminApi } from '@/api/admin'

const openReportCount = ref<number | null>(null)
const openInquiryCount = ref<number | null>(null)

let reportsLoaded = false
let inquiriesLoaded = false
let reportsRequest: Promise<void> | null = null
let inquiriesRequest: Promise<void> | null = null
let requestGeneration = 0

function loadReports(force = false): Promise<void> {
  if (reportsRequest) return reportsRequest
  if (reportsLoaded && !force) return Promise.resolve()

  const generation = requestGeneration
  const request = adminApi.getReports('OPEN', 0, 1)
    .then((response) => {
      if (generation !== requestGeneration) return
      openReportCount.value = response.data.totalElements
      reportsLoaded = true
    })
    .catch((error) => {
      if (generation === requestGeneration) {
        reportsLoaded = false
      }
      console.error('Failed to fetch open report count:', error)
    })
    .finally(() => {
      if (reportsRequest === request) {
        reportsRequest = null
      }
    })

  reportsRequest = request
  return request
}

function loadInquiries(force = false): Promise<void> {
  if (inquiriesRequest) return inquiriesRequest
  if (inquiriesLoaded && !force) return Promise.resolve()

  const generation = requestGeneration
  const request = adminApi.getInquiries('OPEN', 0, 1)
    .then((response) => {
      if (generation !== requestGeneration) return
      openInquiryCount.value = response.data.totalElements
      inquiriesLoaded = true
    })
    .catch((error) => {
      if (generation === requestGeneration) {
        inquiriesLoaded = false
      }
      console.error('Failed to fetch open inquiry count:', error)
    })
    .finally(() => {
      if (inquiriesRequest === request) {
        inquiriesRequest = null
      }
    })

  inquiriesRequest = request
  return request
}

function load(force = false): Promise<void> {
  return Promise.all([
    loadReports(force),
    loadInquiries(force),
  ]).then(() => undefined)
}

/**
 * Resets the module-level state for isolated consumers and tests. In-flight
 * requests are allowed to finish but cannot overwrite the next generation.
 */
export function resetAdminModerationCounts() {
  requestGeneration += 1
  reportsLoaded = false
  inquiriesLoaded = false
  reportsRequest = null
  inquiriesRequest = null
  openReportCount.value = null
  openInquiryCount.value = null
}

export function useAdminModerationCounts() {
  return {
    openReportCount,
    openInquiryCount,
    load,
    loadReports,
    loadInquiries,
    refresh: () => load(true),
  }
}
