package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime

interface RefreshTokenRepository : JpaRepository<RefreshToken, Long> {
    fun findByToken(token: String): RefreshToken?

    @Query("select r from RefreshToken r join fetch r.member order by r.lastUsed desc")
    fun findAllWithMemberOrderByLastUsedDesc(): List<RefreshToken>

    @EntityGraph(attributePaths = ["member"])
    fun findAllByMemberIdOrderByLastUsedDesc(id: Long): List<RefreshToken>

    fun findAllByValidUntilIsBefore(now: LocalDateTime): List<RefreshToken>

}
