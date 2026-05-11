export const releaseNoteCategories = [
  "feature",
  "improvement",
  "fix",
  "maintenance",
  "security"
] as const

export type ReleaseNoteCategory = (typeof releaseNoteCategories)[number]

export const releaseNoteAreas = [
  "admin",
  "attachments",
  "auth",
  "calendar",
  "dashboard",
  "docs",
  "duty",
  "friends",
  "guide",
  "infra",
  "localization",
  "maintenance",
  "notifications",
  "policy",
  "profile",
  "schedule",
  "security",
  "team",
  "todo",
  "ui"
] as const

export type ReleaseNoteArea = (typeof releaseNoteAreas)[number]

export interface ReleaseNoteMeta {
  id: string
  version: string
  date: string
  pr: number
  url: string
  category: ReleaseNoteCategory
  areas: readonly ReleaseNoteArea[]
}

export interface ReleaseNoteCopy {
  title: string
  summary: string
  changes: string[]
}

export interface ReleaseNotesMessages<ReleaseNoteId extends string = string> {
  title: string
  description: string
  count: string
  loadMore: string
  latest: string
  pr: string
  openedAt: string
  areas: string
  categories: Record<ReleaseNoteCategory, string>
  areaLabels: Record<ReleaseNoteArea, string>
  entries: Record<ReleaseNoteId, ReleaseNoteCopy>
}
