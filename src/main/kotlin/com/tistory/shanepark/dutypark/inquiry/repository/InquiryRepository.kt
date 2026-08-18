package com.tistory.shanepark.dutypark.inquiry.repository

import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDateTime
import java.util.UUID

interface InquiryRepository : JpaRepository<Inquiry, UUID> {

    fun countByIpAddressAndCreatedDateAfter(ipAddress: String, createdDate: LocalDateTime): Long

    @EntityGraph(attributePaths = ["member"])
    fun findAllByOrderByCreatedDateDesc(pageable: Pageable): Page<Inquiry>

    @EntityGraph(attributePaths = ["member"])
    fun findAllByStatusOrderByCreatedDateDesc(status: InquiryStatus, pageable: Pageable): Page<Inquiry>
}
