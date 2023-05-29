package com.tistory.shanepark.dutypark.holiday.domain

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import jakarta.persistence.Column
import jakarta.persistence.Entity
import java.time.LocalDate

@Entity
class Holiday(
    dateName: String,
    isHoliday: Boolean,
    localDate: LocalDate
) : EntityBase() {

    @Column(name = "date_name", nullable = false, length = 50)
    val dateName = dateName

    @Column(name = "is_holiday", nullable = false)
    val isHoliday = isHoliday

    @Column(name = "local_date", nullable = false)
    val localDate: LocalDate = localDate

}
