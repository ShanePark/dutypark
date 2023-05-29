package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap

@Service
@Transactional
class HolidayService(
    private val holidayRepository: HolidayRepository,
    @Qualifier("holidayAPIDataGoKr")
    private val holidayAPI: HolidayAPI,
) {
    private val holidayMap: MutableMap<Int, List<HolidayDto>> = ConcurrentHashMap()
    val log: Logger = LoggerFactory.getLogger(this::class.java)

    fun findHolidays(calendarView: CalendarView): Array<List<HolidayDto>> {
        val answer = Array<List<HolidayDto>>(calendarView.size) { emptyList() }
        val years: Set<Int> = calendarView.getRangeYears()
        val holidaysInRange: List<HolidayDto> = holidaysInRangeFromMemory(years)

        for (holiday in holidaysInRange) {
            val holidayDate = holiday.localDate
            if (calendarView.isInRange(holidayDate)) {
                val index = calendarView.getIndex(holidayDate)
                answer[index] = answer[index].plus(holiday)
            }
        }

        return answer
    }

    fun resetHolidayInfo() {
        holidayRepository.deleteAll()
        holidayMap.clear()
        log.info("Holiday info has been reset.")
    }

    private fun holidaysInRangeFromMemory(years: Set<Int>): List<HolidayDto> {
        val holidaysInRange: MutableList<HolidayDto> = ArrayList()
        for (year in years) {
            if (holidayMap[year] == null) {
                holidayMap[year] = holidaysFromDatabase(year)
            }
            holidayMap[year]?.let { holidaysInRange.addAll(it) }
        }
        return holidaysInRange
    }

    private fun holidaysFromDatabase(year: Int): List<HolidayDto> {
        val start = LocalDate.of(year, 1, 1)
        val end = LocalDate.of(year, 12, 31)
        var holidaysOfYear = holidayRepository.findAllByLocalDateBetween(start, end)
        if (holidaysOfYear.isEmpty()) {
            holidaysOfYear = loadAndSaveHolidaysFromAPI(year)
        }
        return holidaysOfYear.map { HolidayDto.of(it) }
    }

    private fun loadAndSaveHolidaysFromAPI(year: Int): List<Holiday> {
        val holidays = holidayAPI.requestHolidays(year)
            .map { holiday -> Holiday(holiday.dateName, holiday.isHoliday, holiday.localDate) }
        holidayRepository.saveAll(holidays)
        return holidays
    }

}
