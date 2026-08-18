package com.tistory.shanepark.dutypark.inquiry.repository

import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import jakarta.persistence.LockModeType
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDateTime
import java.util.Optional
import java.util.UUID

interface InquiryRepository : JpaRepository<Inquiry, UUID> {

    fun countByIpAddressAndCreatedDateAfter(ipAddress: String, createdDate: LocalDateTime): Long

    @EntityGraph(attributePaths = ["member"])
    fun findAllByOrderByCreatedDateDesc(pageable: Pageable): Page<Inquiry>

    @EntityGraph(attributePaths = ["member"])
    fun findAllByStatusOrderByCreatedDateDesc(status: InquiryStatus, pageable: Pageable): Page<Inquiry>

    fun findAllByMemberIdOrderByCreatedDateDesc(memberId: Long, pageable: Pageable): Page<Inquiry>

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select inquiry from Inquiry inquiry where inquiry.id = :id")
    fun findByIdForUpdate(@Param("id") id: UUID): Optional<Inquiry>
}
