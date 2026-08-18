import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: { get: vi.fn() },
}))

import apiClient from './client'
import { publicContentApi, type GuideContent } from './publicContent'

const guide: GuideContent = {
  schemaVersion: 1,
  contentVersion: '2026-08-15',
  locale: 'ko' as const,
  title: '사용 가이드',
  description: '듀티파크 사용법',
  actions: {
    expandAll: '모두 펼치기',
    collapseAll: '모두 접기',
  },
  footer: '더 편리하게 사용하세요.',
  sections: [
    {
      id: 'schedule',
      title: '일정',
      summary: '일정을 관리해요.',
      icon: 'calendar',
      tone: 'success',
      cards: [
        {
          id: 'create-schedule',
          title: '일정 등록',
          icon: 'plus',
          tone: 'accent',
          items: ['날짜를 선택하세요.', '일정을 저장하세요.'],
        },
      ],
    },
  ],
}

const releaseNotes = {
  schemaVersion: 1,
  contentVersion: '2026-08-15',
  locale: 'en' as const,
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
  items: [
    {
      id: '42',
      version: '1.2.0',
      date: '2026-08-15',
      pr: 42,
      url: 'https://github.com/example/dutypark/pull/42',
      category: 'feature' as const,
      areas: ['web'],
      title: 'Native content',
      summary: 'Share public content across clients.',
      changes: ['Added a public content API.'],
    },
  ],
  page: 2,
  size: 10,
  totalElements: 31,
  totalPages: 4,
  hasNext: true,
}

describe('publicContentApi', () => {
  beforeEach(() => vi.clearAllMocks())

  it('loads the guide for the requested locale', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({ data: guide })

    await expect(publicContentApi.getGuide('ko')).resolves.toBe(guide)

    expect(guide.actions).toEqual({
      expandAll: '모두 펼치기',
      collapseAll: '모두 접기',
    })

    expect(guide.sections[0]).toMatchObject({
      icon: 'calendar',
      tone: 'success',
      cards: [{ icon: 'plus', tone: 'accent' }],
    })

    expect(apiClient.get).toHaveBeenCalledWith('/public-content/guide', {
      params: { locale: 'ko' },
    })
  })

  it('loads a release-note page with the requested locale and pagination', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({ data: releaseNotes })

    await expect(
      publicContentApi.getReleaseNotes('en', 2, 10)
    ).resolves.toBe(releaseNotes)

    expect(releaseNotes.labels).toMatchObject({
      count: '{count} changes',
      loadMore: 'Load more',
      pr: 'PR #{number}',
      areas: 'Areas',
    })

    expect(apiClient.get).toHaveBeenCalledWith('/public-content/release-notes', {
      params: { locale: 'en', page: 2, size: 10 },
    })
  })

  it('rejects an unsupported guide schema version', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({
      data: { ...guide, schemaVersion: 2 },
    })

    await expect(publicContentApi.getGuide('ko')).rejects.toThrow(
      'Unsupported public content schema version: 2',
    )
  })

  it('rejects an unsupported release-note schema version', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({
      data: { ...releaseNotes, schemaVersion: 2 },
    })

    await expect(
      publicContentApi.getReleaseNotes('en', 1, 10),
    ).rejects.toThrow('Unsupported public content schema version: 2')
  })
})
