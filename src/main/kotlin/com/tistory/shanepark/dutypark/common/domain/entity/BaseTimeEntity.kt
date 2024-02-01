package com.tistory.shanepark.dutypark.common.domain.entity

import com.tistory.shanepark.dutypark.common.domain.dto.BaseTimeDto
import jakarta.persistence.Column
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
    @Column(name = "modified_date", updatable = true)
    var modifiedDate: LocalDateTime? = null

    @CreatedDate
    @Column(name = "created_date", updatable = false)
    var createdDate: LocalDateTime? = null

    fun baseTimeDto() = BaseTimeDto(this)
}
