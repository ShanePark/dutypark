package com.tistory.shanepark.dutypark.publiccontent.service

import com.tistory.shanepark.dutypark.TestUtils
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesSource
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.core.io.ClassPathResource
import tools.jackson.module.kotlin.readValue
import java.security.MessageDigest

class PublicContentServiceTest {

    private val jsonMapper = TestUtils.jsr310JsonMapper()
    private val service = PublicContentService(jsonMapper)
    private val canonicalReleaseNotes = ClassPathResource("public-content/release-notes.json")
        .inputStream.use { inputStream ->
            jsonMapper.readValue<ReleaseNotesSource>(inputStream)
        }

    @Test
    fun `guide preserves canonical section and card order`() {
        val guide = service.getGuide("ko")

        assertThat(guide.schemaVersion).isEqualTo(1)
        assertThat(guide.locale).isEqualTo("ko")
        assertThat(guide.title).isEqualTo("이용 안내")
        assertThat(guide.actions.expandAll).isEqualTo("모두 펼치기")
        assertThat(guide.actions.collapseAll).isEqualTo("모두 접기")
        assertThat(guide.contentVersion).isEqualTo(sha256("public-content/guide.json"))
        assertThat(service.getGuide("en").contentVersion).isEqualTo(guide.contentVersion)
        assertThat(guide.sections.map { it.id })
            .containsExactly("dashboard", "calendar", "team", "friends", "settings")
        assertThat(guide.sections.first().cards.map { it.id })
            .containsExactly("today", "friends")
        assertThat(guide.sections.sumOf { it.cards.size }).isEqualTo(30)
        assertThat(guide.sections.sumOf { section -> section.cards.sumOf { it.items.size } }).isEqualTo(107)
    }

    @Test
    fun `guide merges locale independent visuals into every section and card`() {
        val guide = service.getGuide("ko")

        val dashboard = guide.sections.first { it.id == "dashboard" }
        assertThat(dashboard.icon).isEqualTo("home")
        assertThat(dashboard.tone).isEqualTo("accent")
        assertThat(dashboard.cards.first { it.id == "friends" }.icon).isEqualTo("users")
        assertThat(dashboard.cards.first { it.id == "friends" }.tone).isEqualTo("neutral")

        val settings = guide.sections.first { it.id == "settings" }
        assertThat(settings.icon).isEqualTo("settings")
        assertThat(settings.tone).isEqualTo("muted")
        assertThat(settings.cards.first { it.id == "theme" }.icon).isEqualTo("sun")
        assertThat(settings.cards.first { it.id == "theme" }.tone).isEqualTo("warning")

        assertThat(guide.sections.flatMap { section ->
            listOf(section.icon) + section.cards.map { it.icon }
        }).allMatch { it.isNotBlank() }
    }

    @Test
    fun `guide visuals are identical across locales for the same ids`() {
        fun visualShape(locale: String) = service.getGuide(locale).sections.map { section ->
            Triple(section.id, section.icon to section.tone, section.cards.map { it.id to (it.icon to it.tone) })
        }

        assertThat(visualShape("ko")).isEqualTo(visualShape("en"))
    }

    @Test
    fun `release notes merge locale copy with metadata and preserve escaped text as rendered text`() {
        val canonicalItems = canonicalReleaseNotes.items
        val latestMetadata = canonicalItems.first()
        val latestCopy = canonicalReleaseNotes.locales.getValue("ko").entries.getValue(latestMetadata.id)
        val page = service.getReleaseNotes(locale = "ko", page = 0, size = 50)

        assertThat(page.totalElements).isEqualTo(canonicalItems.size)
        assertThat(page.items.first().id).isEqualTo(latestMetadata.id)
        assertThat(page.items.first().title).isEqualTo(latestCopy.title)
        assertThat(page.labels.categoryLabels["feature"]).isEqualTo("기능")
        assertThat(page.labels.count).isEqualTo("총 {count}개의 변경사항")
        assertThat(page.labels.loadMore).isEqualTo("더보기")
        assertThat(page.labels.pr).isEqualTo("PR #{number}")
        assertThat(page.labels.areas).isEqualTo("영역")
        assertThat(page.contentVersion).isEqualTo(sha256("public-content/release-notes.json"))
        assertThat(service.getReleaseNotes("ko", 4, 7).contentVersion).isEqualTo(page.contentVersion)

        val allNotes = (0 until page.totalPages)
            .flatMap { service.getReleaseNotes("en", it, 50).items }
        val canonicalChangeCount = canonicalItems.sumOf { metadata ->
            canonicalReleaseNotes.locales.getValue("en").entries.getValue(metadata.id).changes.size
        }
        assertThat(allNotes.sumOf { it.changes.size }).isEqualTo(canonicalChangeCount)
        val componentNote = allNotes.first { it.title.contains("Component annotation") }
        assertThat(componentNote.title).contains("@Component")
        assertThat(componentNote.title).doesNotContain("{'@'}")
        assertThat(allNotes.flatMap { it.changes }).anyMatch { it.contains("{memberId}") }
    }

    @Test
    fun `release notes paginate without reordering`() {
        val firstPage = service.getReleaseNotes(locale = "ko", page = 0, size = 5)
        val secondPage = service.getReleaseNotes(locale = "ko", page = 1, size = 5)
        val expectedTotalPages = (canonicalReleaseNotes.items.size + firstPage.size - 1) / firstPage.size

        assertThat(firstPage.items).hasSize(5)
        assertThat(firstPage.items.map { it.id }).doesNotContainAnyElementsOf(secondPage.items.map { it.id })
        assertThat(firstPage.page).isZero()
        assertThat(firstPage.size).isEqualTo(5)
        assertThat(firstPage.totalPages).isEqualTo(expectedTotalPages)
        assertThat(firstPage.hasNext).isTrue()

        val beyondLastPage = service.getReleaseNotes(locale = "ko", page = Int.MAX_VALUE, size = 5)
        assertThat(beyondLastPage.items).isEmpty()
        assertThat(beyondLastPage.hasNext).isFalse()
    }

    @Test
    fun `banned words are served in the normalized form clients match against`() {
        val bannedWords = service.getBannedWords()

        assertThat(bannedWords.schemaVersion).isEqualTo(1)
        assertThat(bannedWords.contentVersion).isEqualTo(sha256("public-content/banned-words.json"))
        assertThat(bannedWords.words).isNotEmpty
        assertThat(bannedWords.words).doesNotHaveDuplicates()
        assertThat(bannedWords.words).allMatch { word -> word.isNotBlank() }
        assertThat(bannedWords.words).allMatch { word -> word == word.lowercase() }
        assertThat(bannedWords.words).allMatch { word -> word.all(Char::isLetterOrDigit) }
    }

    @Test
    fun `banned words exclude everyday superstrings that substring matching would flag`() {
        val words = service.getBannedWords().words

        // Clients match by substring, so these would block ordinary text such as
        // "보지 못했다", "자지 않았다", "grape", "title", "cocktail" or "assassin".
        assertThat(words).doesNotContain("보지", "자지", "미친", "씹", "rape", "tit", "cock", "ass", "sex")
    }

    @Test
    fun `no banned word contains another so the list stays minimal`() {
        val words = service.getBannedWords().words

        assertThat(words.filter { word -> words.any { other -> other != word && word.contains(other) } }).isEmpty()
    }

    @Test
    fun `validateContent uses the same normalized substring matching as clients`() {
        val exception = assertThrows<BadRequestException> {
            service.validateContent("시.발")
        }

        assertThat(exception.message).isEqualTo("contentFilter.blocked")
        service.validateContent("시민 안내")
    }

    @Test
    fun `normalization keeps supplementary-plane letters when matching`() {
        val supplementaryLetter = String(Character.toChars(0x10400))

        assertDoesNotThrow {
            service.validateContent("f${supplementaryLetter}uck")
        }
    }

    private fun sha256(path: String): String {
        val bytes = ClassPathResource(path).inputStream.use { it.readBytes() }
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte) }
    }
}
