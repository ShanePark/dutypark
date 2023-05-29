package com.tistory.shanepark.dutypark.holiday.repository

import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDate
import java.util.*

interface HolidayRepository : JpaRepository<Holiday, UUID> {

    fun findAllByLocalDateBetween(start: LocalDate, end: LocalDate): List<Holiday>
}
