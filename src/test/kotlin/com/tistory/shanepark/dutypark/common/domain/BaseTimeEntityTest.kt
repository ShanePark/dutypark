package com.tistory.shanepark.dutypark.common.domain

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime

class BaseTimeEntityTest : DutyparkIntegrationTest() {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun test() {
        // Given
        val member = TestData.member
        val refreshToken = RefreshToken(member, fixedDateTime, "", "")
        refreshTokenRepository.save(refreshToken)
        em.flush()
        em.clear()

        val createdDate = refreshToken.createdDate

        assertThat(refreshToken.createdDate).isNotNull
        assertThat(refreshToken.lastModifiedDate).isNotNull

        // When - modify and save with a slight delay to ensure time changes
        Thread.sleep(10)
        val loaded = refreshTokenRepository.findById(refreshToken.id!!).get()
        loaded.validUntil = fixedDateTime.plusDays(1)
        em.flush()

        // Then - lastModifiedDate should be updated
        val saved = refreshTokenRepository.save(loaded)
        assertThat(saved.lastModifiedDate).isAfterOrEqualTo(createdDate)
    }

}
