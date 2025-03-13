package com.tistory.shanepark.dutypark.common.domain.dto

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.time.Month
import java.time.YearMonth

class CalendarViewTest {
    @Test
    fun `jan 2023`() {
        val calendarView = CalendarView(YearMonth.of(2023, 1))
        assertThat(calendarView.prevMonth).isEqualTo(YearMonth.of(2022, 12))
        assertThat(calendarView.paddingBefore).isEqualTo(0)
        assertThat(calendarView.currentMonth).isEqualTo(YearMonth.of(2023, 1))
        assertThat(calendarView.lengthOfMonth).isEqualTo(31)
        assertThat(calendarView.nextMonth).isEqualTo(YearMonth.of(2023, 2))
        assertThat(calendarView.paddingAfter).isEqualTo(4)
        assertThat(calendarView.size).isEqualTo(35)
        assertThat(calendarView.rangeFromDateTime).isEqualTo("2023-01-01T00:00")
        assertThat(calendarView.rangeUntilDateTime).isEqualTo("2023-02-04T23:59:59")
    }

    @Test
    fun `Sep 2023`() {
        val calendarView = CalendarView(YearMonth.of(2023, 9))
        assertThat(calendarView.prevMonth).isEqualTo(YearMonth.of(2023, 8))
        assertThat(calendarView.paddingBefore).isEqualTo(5)
        assertThat(calendarView.currentMonth).isEqualTo(YearMonth.of(2023, 9))
        assertThat(calendarView.lengthOfMonth).isEqualTo(30)
        assertThat(calendarView.nextMonth).isEqualTo(YearMonth.of(2023, 10))
        assertThat(calendarView.paddingAfter).isEqualTo(0)
        assertThat(calendarView.size).isEqualTo(35)
        assertThat(calendarView.rangeFromDateTime).isEqualTo("2023-08-27T00:00")
        assertThat(calendarView.rangeUntilDateTime).isEqualTo("2023-09-30T23:59:59")
    }

    @Test
    fun `is in range`() {
        val calendarView = CalendarView(YearMonth.of(2023, Month.APRIL))
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 25))).isFalse
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 26))).isTrue
        for (i in 1..calendarView.currentMonth.lengthOfMonth()) {
            assertThat(calendarView.isInRange(LocalDate.of(2023, Month.APRIL, i))).isTrue
        }
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 6))).isTrue
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 7))).isFalse
    }

    @Test
    fun `get index`() {
        val calendarView = CalendarView(YearMonth.of(2023, Month.APRIL))
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 25))).isEqualTo(-1)
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 26))).isEqualTo(0)
        for (i in 1..calendarView.currentMonth.lengthOfMonth()) {
            val target = LocalDate.of(2023, Month.APRIL, i)
            assertThat(calendarView.getIndex(target)).isEqualTo(calendarView.paddingBefore + i - 1)
        }
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MAY, 6))).isEqualTo(41)
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MAY, 7))).isEqualTo(-1)
    }

    @Test
    fun `get days returns calendar view days`() {
        // Given
        val calendarView = CalendarView(YearMonth.of(2025, Month.MARCH))

        // When
        val days = calendarView.getRangeDate().toList()

        // Then
        assertThat(days).hasSize(42)
        assertThat(days[0]).isEqualTo(LocalDate.of(2025, Month.FEBRUARY, 23))
        assertThat(days[41]).isEqualTo(LocalDate.of(2025, Month.APRIL, 5))
    }

}
