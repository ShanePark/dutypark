package com.tistory.shanepark.dutypark.publiccontent.service

import com.tistory.shanepark.dutypark.TestUtils
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.core.io.ClassPathResource
import java.security.MessageDigest

class PublicContentServiceTest {

    private val service = PublicContentService(TestUtils.jsr310JsonMapper())

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
        val page = service.getReleaseNotes(locale = "ko", page = 0, size = 50)

        assertThat(page.totalElements).isEqualTo(275)
        assertThat(page.items.first().id).isEqualTo("pr-406")
        assertThat(page.items.first().title).isEqualTo("신고·차단과 앱 내 문의 답변 추가")
        assertThat(page.labels.categoryLabels["feature"]).isEqualTo("기능")
        assertThat(page.labels.count).isEqualTo("총 {count}개의 변경사항")
        assertThat(page.labels.loadMore).isEqualTo("더보기")
        assertThat(page.labels.pr).isEqualTo("PR #{number}")
        assertThat(page.labels.areas).isEqualTo("영역")
        assertThat(page.contentVersion).isEqualTo(sha256("public-content/release-notes.json"))
        assertThat(service.getReleaseNotes("ko", 4, 7).contentVersion).isEqualTo(page.contentVersion)

        val allNotes = (0 until page.totalPages)
            .flatMap { service.getReleaseNotes("en", it, 50).items }
        assertThat(allNotes.sumOf { it.changes.size }).isEqualTo(490)
        val componentNote = allNotes.first { it.title.contains("Component annotation") }
        assertThat(componentNote.title).contains("@Component")
        assertThat(componentNote.title).doesNotContain("{'@'}")
        assertThat(allNotes.flatMap { it.changes }).anyMatch { it.contains("{memberId}") }
    }

    @Test
    fun `release notes paginate without reordering`() {
        val firstPage = service.getReleaseNotes(locale = "ko", page = 0, size = 5)
        val secondPage = service.getReleaseNotes(locale = "ko", page = 1, size = 5)

        assertThat(firstPage.items).hasSize(5)
        assertThat(firstPage.items.map { it.id }).doesNotContainAnyElementsOf(secondPage.items.map { it.id })
        assertThat(firstPage.page).isZero()
        assertThat(firstPage.size).isEqualTo(5)
        assertThat(firstPage.totalPages).isEqualTo(55)
        assertThat(firstPage.hasNext).isTrue()

        val beyondLastPage = service.getReleaseNotes(locale = "ko", page = Int.MAX_VALUE, size = 5)
        assertThat(beyondLastPage.items).isEmpty()
        assertThat(beyondLastPage.hasNext).isFalse()
    }

    private fun sha256(path: String): String {
        val bytes = ClassPathResource(path).inputStream.use { it.readBytes() }
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte) }
    }
}
