package com.tistory.shanepark.dutypark.common.entity

import jakarta.persistence.EntityListeners
import jakarta.persistence.MappedSuperclass
import org.springframework.data.annotation.CreatedDate
import org.springframework.data.annotation.LastModifiedDate
import org.springframework.data.jpa.domain.support.AuditingEntityListener
import java.time.LocalDateTime

@MappedSuperclass
@EntityListeners(AuditingEntityListener::class)
abstract class BaseTimeEntity {
    @LastModifiedDate
    var modifiedDate: LocalDateTime? = null

    @CreatedDate
    var createdDate: LocalDateTime? = null
}
