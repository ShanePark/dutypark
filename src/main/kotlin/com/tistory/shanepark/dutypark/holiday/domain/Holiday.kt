package com.tistory.shanepark.dutypark.holiday.domain

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import jakarta.persistence.Column
import jakarta.persistence.Entity
import java.time.LocalDate

@Entity
class Holiday(
    @Column(name = "date_name", nullable = false, length = 50)
    val dateName: String,
    @Column(name = "is_holiday", nullable = false)
    val isHoliday: Boolean,
    @Column(name = "local_date", nullable = false)
    val localDate: LocalDate
) : EntityBase()
