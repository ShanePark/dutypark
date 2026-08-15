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
    fun `release notes merge locale copy with metadata and preserve escaped text as rendered text`() {
        val page = service.getReleaseNotes(locale = "en", page = 0, size = 50)

        assertThat(page.totalElements).isEqualTo(272)
        assertThat(page.items.first().id).isEqualTo("pr-403")
        assertThat(page.items.first().title).isEqualTo("Dutypark comes to iPhone")
        assertThat(page.labels.categoryLabels["feature"]).isEqualTo("Feature")
        assertThat(page.labels.count).isEqualTo("{count} release notes")
        assertThat(page.labels.loadMore).isEqualTo("Load more")
        assertThat(page.labels.pr).isEqualTo("PR #{number}")
        assertThat(page.labels.areas).isEqualTo("Areas")
        assertThat(page.contentVersion).isEqualTo(sha256("public-content/release-notes.json"))
        assertThat(service.getReleaseNotes("ko", 4, 7).contentVersion).isEqualTo(page.contentVersion)

        val allNotes = (0 until page.totalPages)
            .flatMap { service.getReleaseNotes("en", it, 50).items }
        assertThat(allNotes.sumOf { it.changes.size }).isEqualTo(479)
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
