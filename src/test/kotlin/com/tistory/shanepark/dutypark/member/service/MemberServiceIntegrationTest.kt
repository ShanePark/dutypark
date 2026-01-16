package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort

class MemberServiceIntegrationTest : DutyparkIntegrationTest() {

    @Test
    fun `Search member with sorting and filtering`() {
        // Given - create members without team assignment
        val member1 = memberRepository.save(Member("xshane", "xshane_email", "pass"))
        val member2 = memberRepository.save(Member("xjenny", "xjenny_email", "pass"))
        val member3 = memberRepository.save(Member("xjohn", "xjohn_email", "pass"))
        val member4 = memberRepository.save(Member("xjane", "xjane_email", "pass"))
        val member5 = memberRepository.save(Member("xjames", "xjames_email", "pass"))

        // When
        val sort = Sort.by("name").ascending()
        val page = PageRequest.of(0, 10, sort)

        // Then - verify search with 'xj' prefix (unique to our test data)
        val searchXj = memberService.searchMembersToInviteTeam(page, "xj")
        assertThat(searchXj.content).hasSize(4)
        assertThat(searchXj.content).isSortedAccordingTo { o1, o2 -> o1.name.compareTo(o2.name) }

        // verify exact match
        val searchXjohn = memberService.searchMembersToInviteTeam(page, "xjohn")
        assertThat(searchXjohn.content.map { it.id }).containsExactly(member3.id)

        // verify partial match
        val searchHan = memberService.searchMembersToInviteTeam(page, "han")
        assertThat(searchHan.content.map { it.id }).containsExactly(member1.id)
    }

    private fun search(page: PageRequest, name: String) = memberService.searchMembersToInviteTeam(page, name)
}
