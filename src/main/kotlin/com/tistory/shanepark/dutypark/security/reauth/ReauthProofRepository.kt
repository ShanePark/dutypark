package com.tistory.shanepark.dutypark.security.reauth

import jakarta.persistence.LockModeType
import jakarta.persistence.QueryHint
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.jpa.repository.QueryHints
import java.util.Optional

interface ReauthProofRepository : JpaRepository<ReauthProof, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("select p from ReauthProof p where p.proofHash = :proofHash")
    fun findByProofHashForUpdate(proofHash: String): Optional<ReauthProof>
}
