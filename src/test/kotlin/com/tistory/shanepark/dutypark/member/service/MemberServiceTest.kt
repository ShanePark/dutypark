package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort

class MemberServiceTest : DutyparkIntegrationTest() {

    @Test
    fun `Search member test`() {
        // Given
        memberRepository.deleteAll()
        val member1 = memberRepository.save(Member("shane", "shane_email", "pass"))
        val member2 = memberRepository.save(Member("jenny", "jenny_email", "pass"))
        val member3 = memberRepository.save(Member("john", "john_email", "pass"))
        val member4 = memberRepository.save(Member("jane", "jane_email", "pass"))
        val member5 = memberRepository.save(Member("james", "james_email", "pass"))
        val member6 = memberRepository.save(Member("홍길동", "hong_email", "pass"))
        val member7 = memberRepository.save(Member("김길동", "kim_email", "pass"))
        val member8 = memberRepository.save(Member("박단비", "park_email", "pass"))
        val member9 = memberRepository.save(Member("이단비", "lee_email", "pass"))
        val member10 = memberRepository.save(Member("전이재", "jeon_email", "pass"))
        val member11 = memberRepository.save(Member("민주아", "min_email", "pass"))
        val member12 = memberRepository.save(Member("김민주", "kim2_email", "pass"))

        // When
        val sort = Sort.by("name").ascending()
        val page = PageRequest.of(0, 10, sort)
        val searchAll = memberService.searchMembers(page, "")

        // Then
        assertThat(searchAll.totalElements).isEqualTo(12)
        assertThat(searchAll.content).isSortedAccordingTo { o1, o2 -> o1.name.compareTo(o2.name) }
        assertThat(search(page, "j")).hasSize(4)
        assertThat(search(page, "john").content.map { it.id }).containsExactly(member3.id)
        assertThat(search(page, "han").content.map { it.id }).containsExactly(member1.id)
    }

    private fun search(page: PageRequest, name: String) = memberService.searchMembers(page, name)
}
