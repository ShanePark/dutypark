package com.tistory.shanepark.dutypark.inquiry.domain.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table

/**
 * 문의 생성만 직렬화하는 고정 크기 잠금 행이다. 문의 자체를 잠그지 않아 일반 조회에는 영향을 주지 않는다.
 */
@Entity
@Table(name = "inquiry_rate_limit_lock")
class InquiryRateLimitLock(
    @Id
    @Column(name = "bucket_id", nullable = false)
    val bucketId: Int,
)
