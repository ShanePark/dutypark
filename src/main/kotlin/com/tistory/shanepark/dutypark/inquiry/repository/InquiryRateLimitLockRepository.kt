package com.tistory.shanepark.dutypark.inquiry.repository

import com.tistory.shanepark.dutypark.inquiry.domain.entity.InquiryRateLimitLock
import jakarta.persistence.LockModeType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.Optional

interface InquiryRateLimitLockRepository : JpaRepository<InquiryRateLimitLock, Int> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select rateLimitLock from InquiryRateLimitLock rateLimitLock where rateLimitLock.bucketId = :bucketId")
    fun findByIdForUpdate(@Param("bucketId") bucketId: Int): Optional<InquiryRateLimitLock>
}
