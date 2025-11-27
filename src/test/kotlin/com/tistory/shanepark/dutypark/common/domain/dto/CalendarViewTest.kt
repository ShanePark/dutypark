package com.tistory.shanepark.dutypark.common.domain.dto

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDate
import java.time.Month
import java.time.YearMonth

class CalendarViewTest {

    @Test
    fun `jan 2023 - starts on Sunday, shows previous week`() {
        val calendarView = CalendarView(2023, 1)
        assertThat(CalendarView.SIZE).isEqualTo(42)
        // Jan 1, 2023 is Sunday -> show full previous week (Dec 25-31)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2022, 12, 25))
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2023, 2, 4))
    }

    @Test
    fun `Sep 2023 - starts on Friday`() {
        val calendarView = CalendarView(2023, 9)
        assertThat(CalendarView.SIZE).isEqualTo(42)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2023, 8, 27))
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2023, 10, 7))
    }

    @Test
    fun `2015-02 - Feb starts on Sunday, shows previous week`() {
        val calendarView = CalendarView(2015, 2)
        assertThat(CalendarView.SIZE).isEqualTo(42)
        // Feb 1, 2015 is Sunday -> show full previous week (Jan 25-31)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2015, 1, 25))
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2015, 3, 7))
    }

    @Test
    fun `2026-02 - Feb starts on Sunday, shows previous week`() {
        val calendarView = CalendarView(2026, 2)
        assertThat(CalendarView.SIZE).isEqualTo(42)
        // Feb 1, 2026 is Sunday -> show full previous week (Jan 25-31)
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2026, 1, 25))
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2026, 3, 7))
    }

    @Test
    fun `is in range`() {
        val calendarView = CalendarView(2023, 4)
        val yearMonth = YearMonth.of(2023, 4)
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 25))).isFalse
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MARCH, 26))).isTrue
        for (i in 1..yearMonth.lengthOfMonth()) {
            assertThat(calendarView.isInRange(LocalDate.of(2023, Month.APRIL, i))).isTrue
        }
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 6))).isTrue
        assertThat(calendarView.isInRange(LocalDate.of(2023, Month.MAY, 7))).isFalse
    }

    @Test
    fun `get index`() {
        val calendarView = CalendarView(2023, 4)
        val yearMonth = YearMonth.of(2023, 4)

        assertThrows<IndexOutOfBoundsException> {
            (calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 25)))
        }
        assertThat(calendarView.getIndex(LocalDate.of(2023, Month.MARCH, 26))).isEqualTo(0)
        for (i in 1..yearMonth.lengthOfMonth()) {
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
        // April 1, 2025 = Tuesday, so paddingBefore = 2
        assertThat(calendarView.startDate).isEqualTo(LocalDate.of(2025, 3, 30))
        assertThat(calendarView.rangeFromDateTime).isEqualTo(LocalDate.of(2025, 3, 30).atStartOfDay())

        // Fixed 42 days: March 30 + 41 = May 10
        assertThat(calendarView.endDate).isEqualTo(LocalDate.of(2025, 5, 10))
        assertThat(calendarView.rangeUntilDateTime).isEqualTo(LocalDate.of(2025, 5, 10).atTime(23, 59, 59))
    }

}
