package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.dao.DataIntegrityViolationException

@DataJpaTest
class MemberSocialAccountRepositoryTest {

    @Autowired
    private lateinit var memberRepository: MemberRepository

    @Autowired
    private lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Test
    fun `saveAndFlush rejects duplicate provider and social id`() {
        val member1 = memberRepository.saveAndFlush(Member(name = "user1", email = "user1@duty.park", password = "pass"))
        val member2 = memberRepository.saveAndFlush(Member(name = "user2", email = "user2@duty.park", password = "pass"))

        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member1, provider = SsoType.KAKAO, socialId = "kakao-1")
        )

        assertThrows<DataIntegrityViolationException> {
            memberSocialAccountRepository.saveAndFlush(
                MemberSocialAccount(member = member2, provider = SsoType.KAKAO, socialId = "kakao-1")
            )
        }
    }

    @Test
    fun `saveAndFlush rejects duplicate member and provider`() {
        val member = memberRepository.saveAndFlush(Member(name = "user3", email = "user3@duty.park", password = "pass"))

        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member, provider = SsoType.NAVER, socialId = "naver-1")
        )

        assertThrows<DataIntegrityViolationException> {
            memberSocialAccountRepository.saveAndFlush(
                MemberSocialAccount(member = member, provider = SsoType.NAVER, socialId = "naver-2")
            )
        }
    }

    @Test
    fun `findByProviderAndSocialId returns matching social account`() {
        val member = memberRepository.saveAndFlush(Member(name = "user4", email = "user4@duty.park", password = "pass"))
        val socialAccount = memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member, provider = SsoType.KAKAO, socialId = "kakao-2")
        )

        val found = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, "kakao-2")

        assertThat(found?.id).isEqualTo(socialAccount.id)
        assertThat(found?.member?.id).isEqualTo(member.id)
    }

    @Test
    fun `findAllByMemberIdIn returns social accounts for all requested members`() {
        val member1 = memberRepository.saveAndFlush(Member(name = "user5", email = "user5@duty.park", password = "pass"))
        val member2 = memberRepository.saveAndFlush(Member(name = "user6", email = "user6@duty.park", password = "pass"))
        val otherMember = memberRepository.saveAndFlush(Member(name = "user7", email = "user7@duty.park", password = "pass"))

        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member1, provider = SsoType.KAKAO, socialId = "kakao-3")
        )
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member1, provider = SsoType.NAVER, socialId = "naver-3")
        )
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member2, provider = SsoType.KAKAO, socialId = "kakao-4")
        )
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = otherMember, provider = SsoType.NAVER, socialId = "naver-4")
        )

        val found = memberSocialAccountRepository.findAllByMemberIdIn(setOf(member1.id!!, member2.id!!))

        assertThat(found).hasSize(3)
        assertThat(found.map { it.socialId }).containsExactlyInAnyOrder("kakao-3", "naver-3", "kakao-4")
    }
}
