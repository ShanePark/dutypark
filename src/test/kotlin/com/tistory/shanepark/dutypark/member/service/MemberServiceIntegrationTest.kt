package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort

class MemberServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var blockService: BlockService

    @Test
    fun `Search member with sorting and filtering`() {
        val viewer = TestData.member
        // Given - create members without team assignment
        val member1 = memberRepository.save(Member("xshane", "xshane_email", "pass"))
        val member2 = memberRepository.save(Member("xjenny", "xjenny_email", "pass"))
        val member3 = memberRepository.save(Member("xjohn", "xjohn_email", "pass"))
        val member4 = memberRepository.save(Member("xjane", "xjane_email", "pass"))
        val member5 = memberRepository.save(Member("xjames", "xjames_email", "pass"))

        val sort = Sort.by("name").ascending()
        val page = PageRequest.of(0, 10, sort)

        // Then - verify search with 'xj' prefix (unique to our test data)
        val searchXj = memberService.searchMembersToInviteTeam(page, "xj", viewer.id!!)
        assertThat(searchXj.content).hasSize(4)
        assertThat(searchXj.content).isSortedAccordingTo { o1, o2 -> o1.name.compareTo(o2.name) }
        assertThat(searchXj.content).allSatisfy {
            assertThat(it.teamId).isNull()
            assertThat(it.email).isNotBlank()
        }

        // verify exact match
        val searchXjohn = memberService.searchMembersToInviteTeam(page, "xjohn", viewer.id!!)
        assertThat(searchXjohn.content.map { it.id }).containsExactly(member3.id)

        // verify partial match
        val searchHan = memberService.searchMembersToInviteTeam(page, "han", viewer.id!!)
        assertThat(searchHan.content.map { it.id }).containsExactly(member1.id)
    }

    @Test
    fun `invite candidate search must not include members I blocked`() {
        val viewer = TestData.member
        val target = memberRepository.save(Member("xblocked", "xblocked_email", "pass"))
        memberRepository.save(Member("xvisible", "xvisible_email", "pass"))
        blockService.block(viewer.id!!, target.id!!)
        em.flush()
        em.clear()

        val result = search(PageRequest.of(0, 10), "xblocked", viewer.id!!)

        assertThat(result.content).noneMatch { it.id == target.id }
        assertThat(result.totalElements).isEqualTo(0)
    }

    @Test
    fun `invite candidate search must not include members who blocked me`() {
        val viewer = TestData.member
        val target = memberRepository.save(Member("xblocker", "xblocker_email", "pass"))
        blockService.block(target.id!!, viewer.id!!)
        em.flush()
        em.clear()

        val result = search(PageRequest.of(0, 10), "xblocker", viewer.id!!)

        assertThat(result.content).noneMatch { it.id == target.id }
        assertThat(result.totalElements).isEqualTo(0)
    }

    @Test
    fun `invite candidate search count query excludes blocked members`() {
        val viewer = TestData.member
        val blocked = memberRepository.save(Member("xpage1", "xpage1_email", "pass"))
        val visible = memberRepository.save(Member("xpage2", "xpage2_email", "pass"))
        blockService.block(viewer.id!!, blocked.id!!)
        em.flush()
        em.clear()

        // Page size 1 forces a separate count query, so the totals reveal any unfiltered rows.
        val result = search(PageRequest.of(0, 1, Sort.by("name").ascending()), "xpage", viewer.id!!)

        assertThat(result.totalElements).isEqualTo(1)
        assertThat(result.totalPages).isEqualTo(1)
        assertThat(result.content.map { it.id }).containsExactly(visible.id)
    }

    private fun search(page: PageRequest, name: String, viewerId: Long) =
        memberService.searchMembersToInviteTeam(page, name, viewerId)
}
