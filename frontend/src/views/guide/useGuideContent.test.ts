import { beforeEach, describe, expect, it, vi } from 'vitest'
import type {
  ContentLocale,
  GuideContent,
  ReleaseNoteItem,
  ReleaseNotesContent,
} from '@/api/publicContent'

vi.mock('@/api/publicContent', () => ({
  publicContentApi: {
    getGuide: vi.fn(),
    getReleaseNotes: vi.fn(),
  },
}))

import { publicContentApi } from '@/api/publicContent'
import { useGuideContent } from './useGuideContent'

function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason?: unknown) => void
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise
    reject = rejectPromise
  })
  return { promise, resolve, reject }
}

function guide(locale: ContentLocale): GuideContent {
  return {
    schemaVersion: 1,
    contentVersion: '2026-08-15',
    locale,
    title: locale === 'ko' ? '사용 가이드' : 'User guide',
    description: 'Description',
    actions: {
      expandAll: 'Expand all',
      collapseAll: 'Collapse all',
    },
    footer: 'Footer',
    sections: [],
  }
}

function note(id: string): ReleaseNoteItem {
  return {
    id,
    version: `1.0.${id}`,
    date: '2026-08-15',
    pr: Number(id),
    url: `https://example.com/pull/${id}`,
    category: 'feature',
    areas: ['web'],
    title: `Title ${id}`,
    summary: `Summary ${id}`,
    changes: [`Change ${id}`],
  }
}

function releaseNotes(
  locale: ContentLocale,
  page: number,
  items: ReleaseNoteItem[],
  hasNext: boolean,
): ReleaseNotesContent {
  return {
    schemaVersion: 1,
    contentVersion: '2026-08-15',
    locale,
    labels: {
      title: 'Release notes',
      count: '{count} changes',
      loadMore: 'Load more',
      latest: 'Latest',
      pr: 'PR #{number}',
      areas: 'Areas',
      categoryLabels: { feature: 'Feature' },
      areaLabels: { web: 'Web' },
    },
    items,
    page,
    size: 5,
    totalElements: hasNext ? 6 : page * 5 + items.length,
    totalPages: hasNext ? page + 2 : page + 1,
    hasNext,
  }
}

describe('useGuideContent', () => {
  beforeEach(() => vi.clearAllMocks())

  it('loads guide and release notes independently', async () => {
    const guideRequest = deferred<GuideContent>()
    const releaseRequest = deferred<ReleaseNotesContent>()
    vi.mocked(publicContentApi.getGuide).mockReturnValue(guideRequest.promise)
    vi.mocked(publicContentApi.getReleaseNotes).mockReturnValue(releaseRequest.promise)
    const content = useGuideContent()

    const loading = content.load('ko')

    expect(content.guideLoading.value).toBe(true)
    expect(content.releaseNotesLoading.value).toBe(true)
    expect(publicContentApi.getReleaseNotes).toHaveBeenCalledWith('ko', 0, 5)

    guideRequest.resolve(guide('ko'))
    await guideRequest.promise
    await Promise.resolve()

    expect(content.guideContent.value?.title).toBe('사용 가이드')
    expect(content.guideLoading.value).toBe(false)
    expect(content.releaseNotesLoading.value).toBe(true)

    releaseRequest.resolve(releaseNotes('ko', 0, [note('1')], false))
    await loading

    expect(content.releaseNotesContent.value?.items).toEqual([note('1')])
    expect(content.releaseNotesLoading.value).toBe(false)
  })

  it('does not allow stale responses from the previous locale to overwrite content', async () => {
    const koGuide = deferred<GuideContent>()
    const enGuide = deferred<GuideContent>()
    const koRelease = deferred<ReleaseNotesContent>()
    const enRelease = deferred<ReleaseNotesContent>()
    vi.mocked(publicContentApi.getGuide).mockImplementation(locale =>
      locale === 'ko' ? koGuide.promise : enGuide.promise,
    )
    vi.mocked(publicContentApi.getReleaseNotes).mockImplementation(locale =>
      locale === 'ko' ? koRelease.promise : enRelease.promise,
    )
    const content = useGuideContent()

    const koLoading = content.load('ko')
    const enLoading = content.load('en')
    enGuide.resolve(guide('en'))
    enRelease.resolve(releaseNotes('en', 0, [note('2')], false))
    await enLoading

    koGuide.resolve(guide('ko'))
    koRelease.resolve(releaseNotes('ko', 0, [note('1')], false))
    await koLoading

    expect(content.currentLocale.value).toBe('en')
    expect(content.guideContent.value?.locale).toBe('en')
    expect(content.releaseNotesContent.value?.locale).toBe('en')
    expect(content.releaseNotesContent.value?.items[0]?.id).toBe('2')
  })

  it('surfaces initial errors and retries each resource for the current locale', async () => {
    const guideError = new Error('guide failed')
    const releaseError = new Error('release notes failed')
    vi.mocked(publicContentApi.getGuide)
      .mockRejectedValueOnce(guideError)
      .mockResolvedValueOnce(guide('ko'))
    vi.mocked(publicContentApi.getReleaseNotes)
      .mockRejectedValueOnce(releaseError)
      .mockResolvedValueOnce(releaseNotes('ko', 0, [note('1')], false))
    const content = useGuideContent()

    await content.load('ko')

    expect(content.guideError.value).toBe(guideError)
    expect(content.releaseNotesError.value).toBe(releaseError)
    expect(content.guideLoading.value).toBe(false)
    expect(content.releaseNotesLoading.value).toBe(false)

    await Promise.all([content.retryGuide(), content.retryReleaseNotes()])

    expect(publicContentApi.getGuide).toHaveBeenLastCalledWith('ko')
    expect(publicContentApi.getReleaseNotes).toHaveBeenLastCalledWith('ko', 0, 5)
    expect(content.guideError.value).toBeNull()
    expect(content.releaseNotesError.value).toBeNull()
    expect(content.guideContent.value?.locale).toBe('ko')
    expect(content.releaseNotesContent.value?.items).toEqual([note('1')])
  })

  it('appends release-note pages and updates whether another page exists', async () => {
    vi.mocked(publicContentApi.getGuide).mockResolvedValue(guide('ko'))
    vi.mocked(publicContentApi.getReleaseNotes)
      .mockResolvedValueOnce(releaseNotes('ko', 0, [note('1')], true))
      .mockResolvedValueOnce(releaseNotes('ko', 1, [note('2')], false))
    const content = useGuideContent()
    await content.load('ko')

    expect(content.hasMoreReleaseNotes.value).toBe(true)
    await content.loadMoreReleaseNotes()

    expect(publicContentApi.getReleaseNotes).toHaveBeenLastCalledWith('ko', 1, 5)
    expect(content.releaseNotesContent.value?.items.map(item => item.id)).toEqual(['1', '2'])
    expect(content.releaseNotesContent.value?.page).toBe(1)
    expect(content.hasMoreReleaseNotes.value).toBe(false)
  })

  it('keeps existing release notes when loading more fails and retries the same page', async () => {
    const loadMoreError = new Error('next page failed')
    vi.mocked(publicContentApi.getGuide).mockResolvedValue(guide('ko'))
    vi.mocked(publicContentApi.getReleaseNotes)
      .mockResolvedValueOnce(releaseNotes('ko', 0, [note('1')], true))
      .mockRejectedValueOnce(loadMoreError)
      .mockResolvedValueOnce(releaseNotes('ko', 1, [note('2')], false))
    const content = useGuideContent()
    await content.load('ko')

    await content.loadMoreReleaseNotes()

    expect(content.releaseNotesContent.value?.items.map(item => item.id)).toEqual(['1'])
    expect(content.releaseNotesLoadMoreError.value).toBe(loadMoreError)
    expect(content.releaseNotesLoadingMore.value).toBe(false)

    await content.retryLoadMoreReleaseNotes()

    expect(vi.mocked(publicContentApi.getReleaseNotes).mock.calls.slice(1)).toEqual([
      ['ko', 1, 5],
      ['ko', 1, 5],
    ])
    expect(content.releaseNotesLoadMoreError.value).toBeNull()
    expect(content.releaseNotesContent.value?.items.map(item => item.id)).toEqual(['1', '2'])
  })

  it('reloads page zero without mixing items when content changes during load more', async () => {
    const firstPage = releaseNotes('ko', 0, [note('1')], true)
    const changedNextPage = {
      ...releaseNotes('ko', 1, [note('2')], false),
      contentVersion: '2026-08-16',
    }
    const changedFirstPage = {
      ...releaseNotes('ko', 0, [note('3')], false),
      contentVersion: '2026-08-16',
    }
    vi.mocked(publicContentApi.getGuide).mockResolvedValue(guide('ko'))
    vi.mocked(publicContentApi.getReleaseNotes)
      .mockResolvedValueOnce(firstPage)
      .mockResolvedValueOnce(changedNextPage)
      .mockResolvedValueOnce(changedFirstPage)
    const content = useGuideContent()
    await content.load('ko')

    await content.loadMoreReleaseNotes()

    expect(vi.mocked(publicContentApi.getReleaseNotes).mock.calls).toEqual([
      ['ko', 0, 5],
      ['ko', 1, 5],
      ['ko', 0, 5],
    ])
    expect(content.releaseNotesContent.value?.contentVersion).toBe('2026-08-16')
    expect(content.releaseNotesContent.value?.items.map(item => item.id)).toEqual(['3'])
    expect(content.releaseNotesLoading.value).toBe(false)
    expect(content.releaseNotesLoadingMore.value).toBe(false)
  })

  it('clears stale content and surfaces an error when the version reload fails', async () => {
    const reloadError = new Error('changed content reload failed')
    vi.mocked(publicContentApi.getGuide).mockResolvedValue(guide('ko'))
    vi.mocked(publicContentApi.getReleaseNotes)
      .mockResolvedValueOnce(releaseNotes('ko', 0, [note('1')], true))
      .mockResolvedValueOnce({
        ...releaseNotes('ko', 1, [note('2')], false),
        contentVersion: '2026-08-16',
      })
      .mockRejectedValueOnce(reloadError)
    const content = useGuideContent()
    await content.load('ko')

    await content.loadMoreReleaseNotes()

    expect(vi.mocked(publicContentApi.getReleaseNotes).mock.calls).toEqual([
      ['ko', 0, 5],
      ['ko', 1, 5],
      ['ko', 0, 5],
    ])
    expect(content.releaseNotesContent.value).toBeNull()
    expect(content.releaseNotesError.value).toBe(reloadError)
    expect(content.releaseNotesLoadMoreError.value).toBeNull()
    expect(content.releaseNotesLoading.value).toBe(false)
    expect(content.releaseNotesLoadingMore.value).toBe(false)
  })
})
