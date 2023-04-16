package com.tistory.shanepark.dutypark.common.domain

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime

class BaseTimeEntityTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun test() {
        // Given
        val member = TestData.member
        val refreshToken = RefreshToken(member, LocalDateTime.now(), "", "")
        refreshTokenRepository.save(refreshToken)

        assertThat(refreshToken.createdDate).isNotNull
        assertThat(refreshToken.lastModifiedDate).isNotNull
        assertThat(refreshToken.createdDate).isSameAs(refreshToken.lastModifiedDate)

        // When
        refreshToken.validUntil = LocalDateTime.now()
        em.flush()

        // Then
        val saved = refreshTokenRepository.save(refreshToken)
        assertThat(saved.lastModifiedDate).isAfter(refreshToken.createdDate)
    }

}
