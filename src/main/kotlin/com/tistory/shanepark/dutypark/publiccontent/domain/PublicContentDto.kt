package com.tistory.shanepark.dutypark.publiccontent.domain

data class GuideContentResponse(
    val schemaVersion: Int,
    val contentVersion: String,
    val locale: String,
    val title: String,
    val description: String,
    val actions: GuideActionLabels,
    val footer: String,
    val sections: List<GuideSection>,
)

data class GuideSection(
    val id: String,
    val title: String,
    val summary: String,
    val cards: List<GuideCard>,
)

data class GuideCard(
    val id: String,
    val title: String,
    val items: List<String>,
)

data class GuideActionLabels(
    val expandAll: String,
    val collapseAll: String,
)

data class ReleaseNotesResponse(
    val schemaVersion: Int,
    val contentVersion: String,
    val locale: String,
    val labels: ReleaseNoteLabels,
    val items: List<ReleaseNoteItem>,
    val page: Int,
    val size: Int,
    val totalElements: Int,
    val totalPages: Int,
    val hasNext: Boolean,
)

data class ReleaseNoteLabels(
    val title: String,
    val count: String,
    val loadMore: String,
    val latest: String,
    val pr: String,
    val areas: String,
    val categoryLabels: Map<String, String>,
    val areaLabels: Map<String, String>,
)

data class ReleaseNoteItem(
    val id: String,
    val version: String,
    val date: String,
    val pr: Int,
    val url: String,
    val category: String,
    val areas: List<String>,
    val title: String,
    val summary: String,
    val changes: List<String>,
)

internal data class GuideContentSource(
    val schemaVersion: Int,
    val locales: Map<String, GuideLocaleSource>,
)

internal data class GuideLocaleSource(
    val title: String,
    val description: String,
    val actions: GuideActionLabels,
    val footer: String,
    val sections: List<GuideSection>,
)

internal data class ReleaseNotesSource(
    val schemaVersion: Int,
    val locales: Map<String, ReleaseNoteLocaleSource>,
    val items: List<ReleaseNoteMetadata>,
)

internal data class ReleaseNoteLocaleSource(
    val labels: ReleaseNoteSourceLabels,
    val entries: Map<String, ReleaseNoteCopy>,
)

internal data class ReleaseNoteSourceLabels(
    val title: String,
    val count: String,
    val loadMore: String,
    val latest: String,
    val pr: String,
    val areas: String,
    val categoryLabels: Map<String, String>,
    val areaLabels: Map<String, String>,
)

internal data class ReleaseNoteMetadata(
    val id: String,
    val version: String,
    val date: String,
    val pr: Int,
    val url: String,
    val category: String,
    val areas: List<String>,
)

internal data class ReleaseNoteCopy(
    val title: String,
    val summary: String,
    val changes: List<String>,
)
