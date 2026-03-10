package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.dao.DataIntegrityViolationException

@DataJpaTest
class MemberRepositoryTest {

    @Autowired
    private lateinit var memberRepository: MemberRepository

    @Test
    fun `saveAndFlush rejects duplicate kakao id`() {
        memberRepository.saveAndFlush(
            Member(name = "user1", email = "user1@duty.park", password = "pass").apply {
                kakaoId = "kakao-1"
            }
        )

        assertThrows<DataIntegrityViolationException> {
            memberRepository.saveAndFlush(
                Member(name = "user2", email = "user2@duty.park", password = "pass").apply {
                    kakaoId = "kakao-1"
                }
            )
        }
    }

    @Test
    fun `saveAndFlush rejects duplicate naver id`() {
        memberRepository.saveAndFlush(
            Member(name = "user3", email = "user3@duty.park", password = "pass").apply {
                naverId = "naver-1"
            }
        )

        assertThrows<DataIntegrityViolationException> {
            memberRepository.saveAndFlush(
                Member(name = "user4", email = "user4@duty.park", password = "pass").apply {
                    naverId = "naver-1"
                }
            )
        }
    }
}
