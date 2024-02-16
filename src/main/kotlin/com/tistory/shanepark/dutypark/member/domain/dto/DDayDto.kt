package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import java.time.LocalDate

data class DDayDto(
    val id: Long,
    val title: String,
    val date: LocalDate,
    val isPrivate: Boolean,
    val calc: Long
) {

    val daysLeft: Long = date.toEpochDay() - LocalDate.now().toEpochDay()

    companion object {
        fun of(dDayEvent: DDayEvent): DDayDto {
            var calc = dDayEvent.date.toEpochDay() - LocalDate.now().toEpochDay()
            if (calc < 0)
                calc--
            return DDayDto(
                id = dDayEvent.id!!,
                title = dDayEvent.title,
                date = dDayEvent.date,
                isPrivate = dDayEvent.isPrivate,
                calc = calc
            )
        }
    }
}
