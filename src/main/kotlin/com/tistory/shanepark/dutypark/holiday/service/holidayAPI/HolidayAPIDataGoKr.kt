package com.tistory.shanepark.dutypark.holiday.service.holidayAPI

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.datagokr.DataGoKrApi
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.util.StopWatch
import org.w3c.dom.Element
import org.w3c.dom.NodeList
import java.io.ByteArrayInputStream
import java.nio.charset.Charset
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.stream.Collectors
import java.util.stream.IntStream
import javax.xml.parsers.DocumentBuilderFactory

@Service
class HolidayAPIDataGoKr(
    private val dataGoKrApi: DataGoKrApi,
    @param:Value("\${dutypark.data-go-kr.service-key}") private val serviceKey: String,
) : HolidayAPI {
    private val log = logger()

    override fun requestHolidays(year: Int): List<HolidayDto> {
        val stopWatch = StopWatch()
        stopWatch.start()
        try {
            val result = dataGoKrApi.getHolidays(serviceKey = serviceKey, year = year)
            stopWatch.stop()
            if (stopWatch.totalTimeMillis > 5000) {
                log.warn("DataGoKr API call took {} ms for year {}", stopWatch.totalTimeMillis, year)
            }
            val holidays = parse(result)
            log.info("Holiday API fetch completed: {}", auditContext(mapOf(
                "event" to "holiday_api_fetch_completed", "provider" to "DATA_GO_KR",
                "year" to year, "holidayCount" to holidays.size, "durationMs" to stopWatch.totalTimeMillis,
            )))
            return holidays
        } catch (error: Exception) {
            if (stopWatch.isRunning) stopWatch.stop()
            log.error("Holiday API fetch failed: {}", auditContext(mapOf(
                "event" to "holiday_api_fetch_failed", "provider" to "DATA_GO_KR",
                "year" to year, "durationMs" to stopWatch.totalTimeMillis,
                "exceptionType" to error.javaClass.simpleName,
                "status" to (error as? org.springframework.web.client.RestClientResponseException)?.statusCode?.value(),
            )))
            throw error
        }
    }

    internal fun parse(xmlResult: String): List<HolidayDto> {
        val docBuilder = DocumentBuilderFactory.newInstance().newDocumentBuilder()
        val xmlInput = ByteArrayInputStream(xmlResult.toByteArray(Charset.defaultCharset()))
        val doc = docBuilder.parse(xmlInput)
        val items = doc.getElementsByTagName("item")

        return holidays(items)
    }

    private fun holidays(items: NodeList): List<HolidayDto> {
        return IntStream.range(0, items.length).mapToObj { i ->
            val item = items.item(i) as Element
            val name = item.getElementsByTagName("dateName").item(0).textContent
            val dateString = item.getElementsByTagName("locdate").item(0).textContent
            val localDate = LocalDate.parse(dateString, DateTimeFormatter.ofPattern("yyyyMMdd"))
            val isHoliday = item.getElementsByTagName("isHoliday").item(0).textContent.equals("Y")
            HolidayDto(adjustName(name), isHoliday, localDate)
        }.collect(Collectors.toList())
    }

    private fun adjustName(name: String): String {
        return when (name) {
            "1월1일" -> "신정"
            "기독탄신일" -> "크리스마스"
            else -> name
        }
    }

}
