package com.tistory.shanepark.dutypark.push.apns.domain.repository

import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface ApnsInstallationRepository : JpaRepository<ApnsInstallation, UUID> {
    fun findByDeviceToken(deviceToken: String): ApnsInstallation?

    fun findAllByMemberId(memberId: Long): List<ApnsInstallation>

    fun deleteByMemberIdAndDeviceToken(memberId: Long, deviceToken: String): Int
}
