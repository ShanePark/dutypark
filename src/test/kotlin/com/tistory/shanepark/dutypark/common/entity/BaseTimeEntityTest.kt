package com.tistory.shanepark.dutypark.common.entity

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import jakarta.persistence.EntityManager
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime

class BaseTimeEntityTest :DutyparkIntegrationTest(){

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Autowired
    lateinit var em: EntityManager

    @Test
    fun test() {
        // Given
        val member = TestData.member
        val refreshToken = RefreshToken(member, LocalDateTime.now(), "", "")
        refreshTokenRepository.save(refreshToken)

        assertThat(refreshToken.createdDate).isNotNull
        assertThat(refreshToken.modifiedDate).isNotNull
        assertThat(refreshToken.createdDate).isSameAs(refreshToken.modifiedDate)

        // When
        refreshToken.validUntil = LocalDateTime.now()
        em.flush()

        // Then
        val saved = refreshTokenRepository.save(refreshToken)
        assertThat(saved.modifiedDate).isAfter(refreshToken.createdDate)
    }

}
