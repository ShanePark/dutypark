package com.tistory.shanepark.dutypark.common.domain.dto

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDate
import java.time.Month
import java.time.YearMonth

class CalendarViewTest {
    @Test
    fun `jan 2023`() {
        val calendarView = CalendarView(2023, 1)
        assertThat(calendarView.yearMonth).isEqualTo(YearMonth.of(2023, 1))
        assertThat(calendarView.size).isEqualTo(35)
        assertThat(calendarView.rangeFromDateTime).isEqualTo("2023-01-01T00:00")
        assertThat(calendarView.rangeUntilDateTime).isEqualTo("2023-02-04T23:59:59")
    }

    @Test
    fun `Sep 2023`() {
        val calendarView = CalendarView(2023, 9)
        assertThat(calendarView.yearMonth).isEqualTo(YearMonth.of(2023, 9))
        assertThat(calendarView.size).isEqualTo(35)
        assertThat(calendarView.rangeFromDateTime).isEqualTo("2023-08-27T00:00")
        assertThat(calendarView.rangeUntilDateTime).isEqualTo("2023-09-30T23:59:59")
    }

    @Test
    fun `2015-02 only have 28 days`() {
        val calendarView = CalendarView(2015, 2)
        assertThat(calendarView.yearMonth).isEqualTo(YearMonth.of(2015, 2))
        assertThat(calendarView.size).isEqualTo(28)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2015, 2, 1))
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2015, 2, 28))
    }

    @Test
    fun `is in range`() {
        val calendarView = CalendarView(2023, 4)
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 25))).isFalse
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 26))).isTrue
        for (i in 1..calendarView.yearMonth.lengthOfMonth()) {
            assertThat(calendarView.isInRange(LocalDate.of(2023, Month.APRIL, i))).isTrue
        }
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 6))).isTrue
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 7))).isFalse
    }

    @Test
    fun `get index`() {
        val calendarView = CalendarView(2023, 4)
        assertThrows<IndexOutOfBoundsException> {
            (calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 25)))
        }
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 26))).isEqualTo(0)
        for (i in 1..calendarView.yearMonth.lengthOfMonth()) {
            val target = LocalDate.of(2023, Month.APRIL, i)
            assertThat(calendarView.getIndex(target)).isEqualTo(i + 5)
        }
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MAY, 6))).isEqualTo(41)
        assertThrows<IndexOutOfBoundsException> {
            calendarView.getIndex(LocalDate.of(2023, Month.MAY, 7))
        }
    }

    @Test
    fun `range from , range until`() {
        val calendarView = CalendarView(year = 2025, month = 4)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2025, 3, 30))
        assertThat(calendarView.rangeFromDateTime).isEqualTo(LocalDate.of(2025, 3, 30).atStartOfDay())

        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2025, 5, 3))
        assertThat(calendarView.rangeUntilDateTime).isEqualTo(LocalDate.of(2025, 5, 3).atTime(23, 59, 59))
    }

}
