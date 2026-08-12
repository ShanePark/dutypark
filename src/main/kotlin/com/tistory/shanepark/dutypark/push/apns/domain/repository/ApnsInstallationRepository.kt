package com.tistory.shanepark.dutypark.push.apns.domain.repository

import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime
import java.util.UUID

interface ApnsInstallationRepository : JpaRepository<ApnsInstallation, UUID> {
    fun findByDeviceToken(deviceToken: String): ApnsInstallation?

    @Query(
        """
        select installation
        from ApnsInstallation installation
        join fetch installation.refreshToken token
        where token.member.id = :memberId
          and token.validUntil > :now
        """
    )
    fun findAllDeliverableByMemberId(memberId: Long, now: LocalDateTime): List<ApnsInstallation>

    fun deleteByRefreshTokenIdAndDeviceToken(refreshTokenId: Long, deviceToken: String): Int
}
