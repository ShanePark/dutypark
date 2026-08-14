package com.tistory.shanepark.dutypark.security.oauth.mobile

import jakarta.persistence.LockModeType
import jakarta.persistence.QueryHint
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.jpa.repository.QueryHints
import java.time.Instant
import java.util.Optional

interface MobileOAuthTransactionRepository : JpaRepository<MobileOAuthTransaction, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("select t from MobileOAuthTransaction t where t.stateHash = :stateHash")
    fun findByStateHashForUpdate(stateHash: String): Optional<MobileOAuthTransaction>

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("select t from MobileOAuthTransaction t where t.exchangeCodeHash = :codeHash")
    fun findByExchangeCodeHashForUpdate(codeHash: String): Optional<MobileOAuthTransaction>

    fun deleteAllByStateExpiresAtBefore(expiredBefore: Instant): Int
}
