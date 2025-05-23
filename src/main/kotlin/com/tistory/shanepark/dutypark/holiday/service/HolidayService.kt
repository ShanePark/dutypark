package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.cache.annotation.CacheEvict
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantLock

@Service
@Transactional
class HolidayService(
    private val holidayRepository: HolidayRepository,
    @Qualifier("holidayAPIDataGoKr")
    private val holidayAPI: HolidayAPI,
) {

    private val holidayMap: MutableMap<Int, List<HolidayDto>> = ConcurrentHashMap()
    private val locks: ConcurrentHashMap<Int, ReentrantLock> = ConcurrentHashMap()
    private val log = logger()

    fun findHolidays(calendarView: CalendarView): Array<List<HolidayDto>> {
        val answer = calendarView.makeCalendarArray<HolidayDto>()
        val years: Set<Int> = setOf(calendarView.startDate.year, calendarView.endDate.year)
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

    @CacheEvict(value = ["holidays"], allEntries = true)
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
        val holidaysOfYear = holidayRepository.findAllByLocalDateBetween(start, end)
        if (holidaysOfYear.isEmpty()) {
            return loadAndSaveHolidaysFromAPI(year)
        }
        return holidaysOfYear.map { HolidayDto.of(it) }
    }

    private fun loadAndSaveHolidaysFromAPI(year: Int): List<HolidayDto> {
        val lock = locks.computeIfAbsent(year) { ReentrantLock() }
        lock.lock()
        try {
            val existingHolidays = holidayMap[year]
            if (existingHolidays != null) {
                return existingHolidays
            }

            val holidays = holidayAPI.requestHolidays(year)
                .map { holiday -> Holiday(holiday.dateName, holiday.isHoliday, holiday.localDate) }
            holidayRepository.saveAll(holidays)
            holidayMap[year] = holidays.map { HolidayDto.of(it) }
            return holidays.map { HolidayDto.of(it) }
        } finally {
            lock.unlock()
        }
    }

}
