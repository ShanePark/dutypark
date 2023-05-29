package com.tistory.shanepark.dutypark.holiday.service.holidayAPI

import com.tistory.shanepark.dutypark.common.datagokr.DataGoKrApi
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import org.slf4j.Logger
import org.slf4j.LoggerFactory
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
) : HolidayAPI {

    private val log: Logger = LoggerFactory.getLogger(this::class.java)

    @Value("\${dutypark.data-go-kr.service-key}")
    private lateinit var serviceKey: String

    override fun requestHolidays(year: Int): List<HolidayDto> {
        log.info("Requesting holidays from DataGoKr API...")
        val stopWatch = StopWatch()
        stopWatch.start()
        val result = dataGoKrApi.getHolidays(serviceKey = serviceKey, year = year)
        stopWatch.stop()
        log.info(
            "Holidays from DataGoKr API has been received in {} ms",
            stopWatch.totalTimeMillis
        )
        return parse(result)
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

    /**
     * Some Holiday names on DataGoKr API are not good. So, I change them.
     */
    private fun adjustName(name: String): String {
        return when (name) {
            "1월1일" -> "신정"
            "기독탄신일" -> "크리스마스"
            else -> name
        }
    }

}
