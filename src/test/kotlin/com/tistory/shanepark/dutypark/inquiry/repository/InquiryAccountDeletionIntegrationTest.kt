package com.tistory.shanepark.dutypark.inquiry.repository

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class InquiryAccountDeletionIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var inquiryRepository: InquiryRepository

    @Test
    fun `deleting a member keeps the inquiry and nullifies its member reference`() {
        val member = memberRepository.save(Member(name = "탈퇴예정", email = "leaving@duty.park", password = null))
        val inquiry = inquiryRepository.save(
            Inquiry(
                member = member,
                email = "leaving@duty.park",
                subject = "탈퇴 전 문의",
                content = "탈퇴해도 문의는 남아야 합니다.",
                ipAddress = "127.0.0.1",
            )
        )
        em.flush()
        em.clear()

        em.createNativeQuery("delete from member where id = :id")
            .setParameter("id", member.id!!)
            .executeUpdate()
        em.flush()
        em.clear()

        val reloaded = inquiryRepository.findById(inquiry.id).orElseThrow()
        assertThat(reloaded.member).isNull()
        assertThat(reloaded.content).isEqualTo("탈퇴해도 문의는 남아야 합니다.")
    }
}
