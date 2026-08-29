package com.tistory.shanepark.dutypark.publiccontent.service

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.publiccontent.domain.BannedWordsResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.BannedWordsSource
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideCard
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideContentResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideContentSource
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideSection
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNoteItem
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNoteLabels
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesSource
import org.springframework.core.io.ClassPathResource
import org.springframework.stereotype.Service
import tools.jackson.databind.json.JsonMapper
import tools.jackson.module.kotlin.readValue
import java.security.MessageDigest
import java.text.Normalizer

@Service
class PublicContentService(
    private val jsonMapper: JsonMapper,
) {

    private val guideResource = load<GuideContentSource>(GUIDE_RESOURCE).also { validateGuide(it.content) }
    private val releaseNotesResource = load<ReleaseNotesSource>(RELEASE_NOTES_RESOURCE).also {
        validateReleaseNotes(it.content)
    }
    private val bannedWordsResource = load<BannedWordsSource>(BANNED_WORDS_RESOURCE).let { loaded ->
        loaded.copy(content = loaded.content.copy(words = loaded.content.words.map(::normalizeForMatching)))
    }.also { validateBannedWords(it.content) }

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
            sections = localized.sections.map { section ->
                val sectionVisual = checkNotNull(guide.visuals[section.id])
                GuideSection(
                    id = section.id,
                    title = section.title,
                    summary = section.summary,
                    icon = sectionVisual.icon,
                    tone = sectionVisual.tone,
                    cards = section.cards.map { card ->
                        val cardVisual = checkNotNull(sectionVisual.cards[card.id])
                        GuideCard(
                            id = card.id,
                            title = card.title,
                            icon = cardVisual.icon,
                            tone = cardVisual.tone,
                            items = card.items,
                        )
                    },
                )
            },
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

    fun getBannedWords(): BannedWordsResponse = BannedWordsResponse(
        schemaVersion = bannedWordsResource.content.schemaVersion,
        contentVersion = bannedWordsResource.contentVersion,
        words = bannedWordsResource.content.words,
    )

    /**
     * Applies the same normalization and substring matching as the public banned-words contract.
     * User-generated text must be checked here as well as by clients because API callers can bypass
     * the client-side preflight.
     */
    fun validateContent(value: String) {
        val normalized = normalizeForMatching(value)
        if (bannedWordsResource.content.words.any(normalized::contains)) {
            throw BadRequestException("contentFilter.blocked")
        }
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
        validateGuideVisuals(source)
    }

    /**
     * Visuals are locale-independent, so every section/card id in every locale must resolve to exactly one
     * visual entry and vice versa: drift in either direction must fail startup instead of reaching a client.
     */
    private fun validateGuideVisuals(source: GuideContentSource) {
        source.locales.values.forEach { locale ->
            locale.sections.forEach { section ->
                val sectionVisual = requireNotNull(source.visuals[section.id]) {
                    "Guide section '${section.id}' has no visuals entry"
                }
                section.cards.forEach { card ->
                    requireNotNull(sectionVisual.cards[card.id]) {
                        "Guide card '${section.id}/${card.id}' has no visuals entry"
                    }
                }
            }
        }
        val contentCardIds = source.locales.values
            .flatMap { it.sections }
            .groupBy({ it.id }, { section -> section.cards.map { it.id }.toSet() })
            .mapValues { (_, cardIds) -> cardIds.flatten().toSet() }
        check(source.visuals.keys == contentCardIds.keys) {
            "Guide visuals sections ${source.visuals.keys} do not match content sections ${contentCardIds.keys}"
        }
        source.visuals.forEach { (sectionId, sectionVisual) ->
            check(sectionVisual.cards.keys == contentCardIds.getValue(sectionId)) {
                "Guide visuals cards for section '$sectionId' do not match content cards"
            }
            check(sectionVisual.icon in ICON_KEYS) { "Unknown guide icon '${sectionVisual.icon}'" }
            check(sectionVisual.tone in TONE_KEYS) { "Unknown guide tone '${sectionVisual.tone}'" }
            sectionVisual.cards.forEach { (cardId, cardVisual) ->
                check(cardVisual.icon in ICON_KEYS) { "Unknown guide icon '${cardVisual.icon}' on '$sectionId/$cardId'" }
                check(cardVisual.tone in TONE_KEYS) { "Unknown guide tone '${cardVisual.tone}' on '$sectionId/$cardId'" }
            }
        }
    }

    /**
     * Clients match a banned word as a substring of the same normalization, so the list is stored in that
     * normalized form and must stay flat: an entry containing another entry never matches on its own, and a
     * short entry that occurs inside everyday text would block it everywhere.
     */
    private fun validateBannedWords(source: BannedWordsSource) {
        check(source.schemaVersion == SUPPORTED_SCHEMA_VERSION)
        check(source.words.isNotEmpty())
        check(source.words.all(String::isNotBlank)) { "Banned words must not normalize to an empty string" }
        check(source.words.distinct().size == source.words.size) { "Banned words contain a duplicate" }
        source.words.forEach { word ->
            val redundant = source.words.firstOrNull { other -> other != word && word.contains(other) }
            check(redundant == null) { "Banned word '$word' is already matched by '$redundant'" }
        }
    }

    private fun normalizeForMatching(value: String): String {
        val normalized = Normalizer
            .normalize(value, Normalizer.Form.NFKC)
            .lowercase()
        return buildString {
            normalized.codePoints().forEach { codePoint ->
                if (Character.isLetterOrDigit(codePoint)) {
                    appendCodePoint(codePoint)
                }
            }
        }
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
        private const val BANNED_WORDS_RESOURCE = "public-content/banned-words.json"

        /** Closed vocabularies shared with every client's icon/colour mapping table. */
        private val TONE_KEYS = setOf(
            "accent", "accentLight", "success", "warning", "danger", "neutral", "muted",
        )
        private val ICON_KEYS = setOf(
            "home", "calendar", "calendarCheck", "building", "settings", "users",
            "personAdd", "userCog", "pencil", "spreadsheet", "plus", "sparkles", "eye", "checklist",
            "search", "palette", "sun", "bell", "pin", "trash", "camera", "shield", "phone", "link", "lock",
        )
    }

    private data class LoadedResource<T>(
        val content: T,
        val contentVersion: String,
    )
}
