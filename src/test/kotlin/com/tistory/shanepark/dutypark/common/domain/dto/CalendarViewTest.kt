package com.tistory.shanepark.dutypark.common.domain.dto

import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.YearMonth

class CalendarViewTest {
    @Test
    fun `jan 2023`() {
        val calendarView = CalendarView(YearMonth.of(2023, 1))
        Assertions.assertThat(calendarView.prevMonth).isEqualTo(YearMonth.of(2022, 12))
        Assertions.assertThat(calendarView.paddingBefore).isEqualTo(0)
        Assertions.assertThat(calendarView.currentMonth).isEqualTo(YearMonth.of(2023, 1))
        Assertions.assertThat(calendarView.lengthOfMonth).isEqualTo(31)
        Assertions.assertThat(calendarView.nextMonth).isEqualTo(YearMonth.of(2023, 2))
        Assertions.assertThat(calendarView.paddingAfter).isEqualTo(4)
        Assertions.assertThat(calendarView.size).isEqualTo(35)
        Assertions.assertThat(calendarView.rangeFrom).isEqualTo("2023-01-01T00:00")
        Assertions.assertThat(calendarView.rangeEnd).isEqualTo("2023-02-04T23:59:59")
    }

    @Test
    fun `Sep 2023`() {
        val calendarView = CalendarView(YearMonth.of(2023, 9))
        Assertions.assertThat(calendarView.prevMonth).isEqualTo(YearMonth.of(2023, 8))
        Assertions.assertThat(calendarView.paddingBefore).isEqualTo(5)
        Assertions.assertThat(calendarView.currentMonth).isEqualTo(YearMonth.of(2023, 9))
        Assertions.assertThat(calendarView.lengthOfMonth).isEqualTo(30)
        Assertions.assertThat(calendarView.nextMonth).isEqualTo(YearMonth.of(2023, 10))
        Assertions.assertThat(calendarView.paddingAfter).isEqualTo(0)
        Assertions.assertThat(calendarView.size).isEqualTo(35)
        Assertions.assertThat(calendarView.rangeFrom).isEqualTo("2023-08-27T00:00")
        Assertions.assertThat(calendarView.rangeEnd).isEqualTo("2023-09-30T23:59:59")
    }
}
