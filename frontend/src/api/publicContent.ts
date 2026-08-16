import apiClient from './client'

export type ContentLocale = 'ko' | 'en'

export interface GuideCard {
  id: string
  title: string
  items: string[]
}

export interface GuideSection {
  id: string
  title: string
  summary: string
  cards: GuideCard[]
}

export interface GuideContent {
  schemaVersion: number
  contentVersion: string
  locale: ContentLocale
  title: string
  description: string
  actions: {
    expandAll: string
    collapseAll: string
  }
  footer: string
  sections: GuideSection[]
}

export type ReleaseNoteCategory =
  | 'feature'
  | 'improvement'
  | 'fix'
  | 'maintenance'
  | 'security'

export interface ReleaseNoteLabels {
  title: string
  count: string
  loadMore: string
  latest: string
  pr: string
  areas: string
  categoryLabels: Record<string, string>
  areaLabels: Record<string, string>
}

export interface ReleaseNoteItem {
  id: string
  version: string
  date: string
  pr: number
  url: string
  category: ReleaseNoteCategory
  areas: string[]
  title: string
  summary: string
  changes: string[]
}

export interface ReleaseNotesContent {
  schemaVersion: number
  contentVersion: string
  locale: ContentLocale
  labels: ReleaseNoteLabels
  items: ReleaseNoteItem[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  hasNext: boolean
}

function requireSupportedSchema<T extends { schemaVersion: number }>(
  content: T,
): T {
  if (content.schemaVersion !== 1) {
    throw new Error(
      `Unsupported public content schema version: ${content.schemaVersion}`,
    )
  }
  return content
}

export const publicContentApi = {
  getGuide: async (locale: ContentLocale): Promise<GuideContent> => {
    const response = await apiClient.get<GuideContent>('/public-content/guide', {
      params: { locale },
    })
    return requireSupportedSchema(response.data)
  },

  getReleaseNotes: async (
    locale: ContentLocale,
    page: number,
    size: number
  ): Promise<ReleaseNotesContent> => {
    const response = await apiClient.get<ReleaseNotesContent>(
      '/public-content/release-notes',
      {
        params: { locale, page, size },
      }
    )
    return requireSupportedSchema(response.data)
  },
}
