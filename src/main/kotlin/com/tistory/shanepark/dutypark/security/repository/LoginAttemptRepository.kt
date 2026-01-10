package com.tistory.shanepark.dutypark.security.repository

import com.tistory.shanepark.dutypark.security.domain.entity.LoginAttempt
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime

interface LoginAttemptRepository : JpaRepository<LoginAttempt, Long> {

    @Query(
        """
        SELECT COUNT(la) FROM LoginAttempt la
        WHERE la.ipAddress = :ipAddress
        AND la.email = :email
        AND la.attemptTime > :since
        AND la.success = false
    """
    )
    fun countRecentFailedAttempts(
        ipAddress: String,
        email: String,
        since: LocalDateTime
    ): Long

    @Modifying
    @Query("DELETE FROM LoginAttempt la WHERE la.attemptTime < :threshold")
    fun deleteAllByAttemptTimeBefore(threshold: LocalDateTime): Int

}
