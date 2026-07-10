package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.cache.annotation.CacheEvict
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantLock

@Service
@Transactional
class HolidayService(
    private val holidayRepository: HolidayRepository,
    @param:Qualifier("holidayAPIDataGoKr")
    private val holidayAPI: HolidayAPI,
    private val dutyRepository: DutyRepository,
    private val clock: Clock,
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
    @Transactional(timeout = 20)
    fun resetHolidayInfo() {
        dutyRepository.deleteAutomaticByDutyDateGreaterThanEqual(
            LocalDate.now(clock.withZone(SEOUL))
        )
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
            val cached = holidays.map { HolidayDto.of(it) }
            holidayMap[year] = cached
            evictIfTransactionRollsBack(year, cached)
            return cached
        } finally {
            lock.unlock()
        }
    }

    private fun evictIfTransactionRollsBack(year: Int, cached: List<HolidayDto>) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) return
        TransactionSynchronizationManager.registerSynchronization(object : TransactionSynchronization {
            override fun afterCompletion(status: Int) {
                if (status == TransactionSynchronization.STATUS_COMMITTED) return
                holidayMap.computeIfPresent(year) { _, current ->
                    current.takeUnless { it === cached }
                }
            }
        })
    }

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }

}
