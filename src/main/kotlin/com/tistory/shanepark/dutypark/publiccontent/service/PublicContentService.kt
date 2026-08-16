package com.tistory.shanepark.dutypark.publiccontent.service

import com.tistory.shanepark.dutypark.publiccontent.domain.GuideContentResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideContentSource
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNoteItem
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNoteLabels
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesSource
import org.springframework.core.io.ClassPathResource
import org.springframework.stereotype.Service
import tools.jackson.databind.json.JsonMapper
import tools.jackson.module.kotlin.readValue
import java.security.MessageDigest

@Service
class PublicContentService(
    private val jsonMapper: JsonMapper,
) {

    private val guideResource = load<GuideContentSource>(GUIDE_RESOURCE).also { validateGuide(it.content) }
    private val releaseNotesResource = load<ReleaseNotesSource>(RELEASE_NOTES_RESOURCE).also {
        validateReleaseNotes(it.content)
    }

    fun getGuide(locale: String): GuideContentResponse {
        val guide = guideResource.content
        val localized = guide.locales[locale] ?: throw IllegalArgumentException("common.badRequest")
        return GuideContentResponse(
            schemaVersion = guide.schemaVersion,
            contentVersion = guideResource.contentVersion,
            locale = locale,
            title = localized.title,
            description = localized.description,
            actions = localized.actions,
            footer = localized.footer,
            sections = localized.sections,
        )
    }

    fun getReleaseNotes(locale: String, page: Int, size: Int): ReleaseNotesResponse {
        require(page >= 0) { "common.badRequest" }
        require(size in 1..50) { "common.badRequest" }
        val releaseNotes = releaseNotesResource.content
        val localized = releaseNotes.locales[locale] ?: throw IllegalArgumentException("common.badRequest")
        val totalElements = releaseNotes.items.size
        val totalPages = (totalElements + size - 1) / size
        val fromIndex = (page.toLong() * size).coerceAtMost(totalElements.toLong()).toInt()
        val toIndex = (fromIndex + size).coerceAtMost(totalElements)
        val items = releaseNotes.items.subList(fromIndex, toIndex).map { metadata ->
            val copy = checkNotNull(localized.entries[metadata.id])
            ReleaseNoteItem(
                id = metadata.id,
                version = metadata.version,
                date = metadata.date,
                pr = metadata.pr,
                url = metadata.url,
                category = metadata.category,
                areas = metadata.areas,
                title = copy.title,
                summary = copy.summary,
                changes = copy.changes,
            )
        }
        return ReleaseNotesResponse(
            schemaVersion = releaseNotes.schemaVersion,
            contentVersion = releaseNotesResource.contentVersion,
            locale = locale,
            labels = ReleaseNoteLabels(
                title = localized.labels.title,
                count = localized.labels.count,
                loadMore = localized.labels.loadMore,
                latest = localized.labels.latest,
                pr = localized.labels.pr,
                areas = localized.labels.areas,
                categoryLabels = localized.labels.categoryLabels,
                areaLabels = localized.labels.areaLabels,
            ),
            items = items,
            page = page,
            size = size,
            totalElements = totalElements,
            totalPages = totalPages,
            hasNext = page < totalPages - 1,
        )
    }

    private inline fun <reified T> load(path: String): LoadedResource<T> = try {
        val bytes = ClassPathResource(path).inputStream.use { it.readBytes() }
        LoadedResource(
            content = jsonMapper.readValue<T>(bytes.inputStream()),
            contentVersion = MessageDigest.getInstance("SHA-256")
                .digest(bytes)
                .joinToString("") { byte -> "%02x".format(byte) },
        )
    } catch (exception: Exception) {
        throw IllegalStateException("Failed to load canonical public content: $path", exception)
    }

    private fun validateGuide(source: GuideContentSource) {
        check(source.schemaVersion == SUPPORTED_SCHEMA_VERSION)
        check(source.locales.keys == SUPPORTED_LOCALES)
        source.locales.values.forEach { locale ->
            check(locale.title.isNotBlank() && locale.description.isNotBlank() && locale.footer.isNotBlank())
            check(locale.actions.expandAll.isNotBlank() && locale.actions.collapseAll.isNotBlank())
            check(locale.sections.isNotEmpty())
            check(locale.sections.map { it.id }.distinct().size == locale.sections.size)
            locale.sections.forEach { section ->
                check(section.id.isNotBlank() && section.title.isNotBlank() && section.summary.isNotBlank())
                check(section.cards.isNotEmpty())
                check(section.cards.map { it.id }.distinct().size == section.cards.size)
                section.cards.forEach { card ->
                    check(card.id.isNotBlank() && card.title.isNotBlank())
                    check(card.items.isNotEmpty() && card.items.all(String::isNotBlank))
                }
            }
        }
        val sectionShape = source.locales.values.map { locale ->
            locale.sections.map { section -> section.id to section.cards.map { it.id to it.items.size } }
        }
        check(sectionShape.distinct().size == 1)
    }

    private fun validateReleaseNotes(source: ReleaseNotesSource) {
        check(source.schemaVersion == SUPPORTED_SCHEMA_VERSION)
        check(source.locales.keys == SUPPORTED_LOCALES)
        check(source.items.isNotEmpty())
        check(source.items.map { it.id }.distinct().size == source.items.size)
        check(source.items.map { it.version }.distinct().size == source.items.size)
        check(source.items.map { it.pr }.distinct().size == source.items.size)
        val ids = source.items.map { it.id }.toSet()
        source.items.forEach { metadata ->
            check(metadata.id == "pr-${metadata.pr}")
            check(metadata.version.isNotBlank() && metadata.date.isNotBlank() && metadata.url.isNotBlank())
            check(metadata.category.isNotBlank() && metadata.areas.isNotEmpty() && metadata.areas.all(String::isNotBlank))
        }
        source.locales.values.forEach { locale ->
            check(locale.entries.keys == ids)
            check(locale.labels.title.isNotBlank() && locale.labels.latest.isNotBlank())
            check(locale.labels.count.isNotBlank() && locale.labels.loadMore.isNotBlank())
            check(locale.labels.pr.isNotBlank() && locale.labels.areas.isNotBlank())
            locale.entries.values.forEach { copy ->
                check(copy.title.isNotBlank() && copy.summary.isNotBlank())
                check(copy.changes.isNotEmpty() && copy.changes.all(String::isNotBlank))
            }
            check(source.items.all { locale.labels.categoryLabels[it.category].isNullOrBlank().not() })
            check(source.items.flatMap { it.areas }.all { locale.labels.areaLabels[it].isNullOrBlank().not() })
        }
    }

    companion object {
        private const val SUPPORTED_SCHEMA_VERSION = 1
        private val SUPPORTED_LOCALES = setOf("ko", "en")
        private const val GUIDE_RESOURCE = "public-content/guide.json"
        private const val RELEASE_NOTES_RESOURCE = "public-content/release-notes.json"
    }

    private data class LoadedResource<T>(
        val content: T,
        val contentVersion: String,
    )
}
