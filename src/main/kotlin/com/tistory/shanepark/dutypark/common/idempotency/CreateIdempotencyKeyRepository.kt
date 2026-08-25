package com.tistory.shanepark.dutypark.common.idempotency

import jakarta.persistence.LockModeType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import java.util.Optional
import java.util.UUID

interface CreateIdempotencyKeyRepository : JpaRepository<CreateIdempotencyKey, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    fun findByMemberIdAndOperationIdAndResourceKind(
        memberId: Long,
        operationId: String,
        resourceKind: CreateIdempotencyResource,
    ): Optional<CreateIdempotencyKey>
}
