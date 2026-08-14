package com.tistory.shanepark.dutypark.security.oauth.web

import jakarta.persistence.LockModeType
import jakarta.persistence.QueryHint
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.jpa.repository.QueryHints
import java.time.Instant
import java.util.Optional

interface WebOAuthTransactionRepository : JpaRepository<WebOAuthTransaction, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("select transaction from WebOAuthTransaction transaction where transaction.stateHash = :stateHash")
    fun findByStateHashForUpdate(stateHash: String): Optional<WebOAuthTransaction>

    fun deleteAllByStateExpiresAtBefore(expiredBefore: Instant): Int
}
