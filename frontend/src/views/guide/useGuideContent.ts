import { computed, ref, shallowRef } from 'vue'
import {
  publicContentApi,
  type ContentLocale,
  type GuideContent,
  type ReleaseNotesContent,
} from '@/api/publicContent'

const RELEASE_NOTES_PAGE_SIZE = 5

export function useGuideContent() {
  const currentLocale = ref<ContentLocale | null>(null)
  const guideContent = ref<GuideContent | null>(null)
  const releaseNotesContent = ref<ReleaseNotesContent | null>(null)

  const guideLoading = ref(false)
  const releaseNotesLoading = ref(false)
  const releaseNotesLoadingMore = ref(false)

  const guideError = shallowRef<unknown | null>(null)
  const releaseNotesError = shallowRef<unknown | null>(null)
  const releaseNotesLoadMoreError = shallowRef<unknown | null>(null)

  let guideRequestId = 0
  let releaseNotesRequestId = 0
  let failedReleaseNotesPage: number | null = null

  const hasMoreReleaseNotes = computed(
    () => releaseNotesContent.value?.hasNext ?? false,
  )

  async function loadGuide(locale: ContentLocale): Promise<void> {
    const requestId = ++guideRequestId
    guideLoading.value = true
    guideError.value = null

    try {
      const response = await publicContentApi.getGuide(locale)
      if (requestId === guideRequestId && currentLocale.value === locale) {
        guideContent.value = response
      }
    } catch (error) {
      if (requestId === guideRequestId && currentLocale.value === locale) {
        guideError.value = error
      }
    } finally {
      if (requestId === guideRequestId && currentLocale.value === locale) {
        guideLoading.value = false
      }
    }
  }

  async function loadFirstReleaseNotesPage(locale: ContentLocale): Promise<void> {
    const requestId = ++releaseNotesRequestId
    releaseNotesLoading.value = true
    releaseNotesLoadingMore.value = false
    releaseNotesError.value = null
    releaseNotesLoadMoreError.value = null
    failedReleaseNotesPage = null

    try {
      const response = await publicContentApi.getReleaseNotes(
        locale,
        0,
        RELEASE_NOTES_PAGE_SIZE,
      )
      if (requestId === releaseNotesRequestId && currentLocale.value === locale) {
        releaseNotesContent.value = response
      }
    } catch (error) {
      if (requestId === releaseNotesRequestId && currentLocale.value === locale) {
        releaseNotesError.value = error
      }
    } finally {
      if (requestId === releaseNotesRequestId && currentLocale.value === locale) {
        releaseNotesLoading.value = false
      }
    }
  }

  async function load(locale: ContentLocale): Promise<void> {
    currentLocale.value = locale
    guideContent.value = null
    releaseNotesContent.value = null
    guideError.value = null
    releaseNotesError.value = null
    releaseNotesLoadMoreError.value = null

    await Promise.all([
      loadGuide(locale),
      loadFirstReleaseNotesPage(locale),
    ])
  }

  function retryGuide(): Promise<void> {
    return currentLocale.value ? loadGuide(currentLocale.value) : Promise.resolve()
  }

  function retryReleaseNotes(): Promise<void> {
    return currentLocale.value
      ? loadFirstReleaseNotesPage(currentLocale.value)
      : Promise.resolve()
  }

  async function loadReleaseNotesPage(page: number): Promise<void> {
    const locale = currentLocale.value
    const existingContent = releaseNotesContent.value
    if (!locale || !existingContent) {
      return
    }

    const requestId = ++releaseNotesRequestId
    releaseNotesLoadingMore.value = true
    releaseNotesLoadMoreError.value = null
    failedReleaseNotesPage = null

    try {
      const response = await publicContentApi.getReleaseNotes(
        locale,
        page,
        RELEASE_NOTES_PAGE_SIZE,
      )
      if (requestId !== releaseNotesRequestId || currentLocale.value !== locale) {
        return
      }

      if (response.contentVersion !== existingContent.contentVersion) {
        releaseNotesContent.value = null
        await loadFirstReleaseNotesPage(locale)
        return
      }

      releaseNotesContent.value = {
        ...response,
        items: [...existingContent.items, ...response.items],
      }
    } catch (error) {
      if (requestId === releaseNotesRequestId && currentLocale.value === locale) {
        releaseNotesLoadMoreError.value = error
        failedReleaseNotesPage = page
      }
    } finally {
      if (requestId === releaseNotesRequestId && currentLocale.value === locale) {
        releaseNotesLoadingMore.value = false
      }
    }
  }

  function loadMoreReleaseNotes(): Promise<void> {
    const content = releaseNotesContent.value
    if (
      !content?.hasNext ||
      releaseNotesLoading.value ||
      releaseNotesLoadingMore.value
    ) {
      return Promise.resolve()
    }

    return loadReleaseNotesPage(content.page + 1)
  }

  function retryLoadMoreReleaseNotes(): Promise<void> {
    if (
      failedReleaseNotesPage === null ||
      releaseNotesLoading.value ||
      releaseNotesLoadingMore.value
    ) {
      return Promise.resolve()
    }

    return loadReleaseNotesPage(failedReleaseNotesPage)
  }

  return {
    currentLocale,
    guideContent,
    releaseNotesContent,
    guideLoading,
    guideError,
    releaseNotesLoading,
    releaseNotesError,
    releaseNotesLoadingMore,
    releaseNotesLoadMoreError,
    hasMoreReleaseNotes,
    load,
    retryGuide,
    retryReleaseNotes,
    loadMoreReleaseNotes,
    retryLoadMoreReleaseNotes,
  }
}
