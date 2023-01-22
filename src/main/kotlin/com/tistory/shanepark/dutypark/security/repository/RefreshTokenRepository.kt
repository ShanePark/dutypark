package com.tistory.shanepark.dutypark.security.repository

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.springframework.data.jpa.repository.JpaRepository

interface RefreshTokenRepository : JpaRepository<RefreshToken, Long> {
    fun findByToken(token: String): RefreshToken?
}
