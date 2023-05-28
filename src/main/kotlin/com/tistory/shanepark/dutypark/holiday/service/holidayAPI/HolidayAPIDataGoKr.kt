package com.tistory.shanepark.dutypark.holiday.service.holidayAPI

import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.util.UriComponentsBuilder
import org.w3c.dom.Element
import org.w3c.dom.NodeList
import java.io.ByteArrayInputStream
import java.net.URLEncoder
import java.nio.charset.Charset
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.stream.Collectors
import java.util.stream.IntStream
import javax.xml.parsers.DocumentBuilderFactory

@Service
class HolidayAPIDataGoKr : HolidayAPI {

    @Value("\${dutypark.data-go-kr.service-key}")
    private lateinit var serviceKey: String

    override fun requestHolidays(year: Int): List<HolidayDto> {
        val client = WebClient.create()
        val encodeServiceKey = URLEncoder.encode(serviceKey, "UTF-8")

        val uri =
            UriComponentsBuilder.fromUriString("https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getHoliDeInfo")
                .queryParam("serviceKey", encodeServiceKey)
                .queryParam("solYear", year)
                .queryParam("numOfRows", 100)
                .build(true)
                .toUri()

        val result = client.get()
            .uri(uri)
            .retrieve()
            .bodyToMono(String::class.java)
            .block()

        return result?.let { parse(it) } ?: emptyList()
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
            HolidayDto(name, isHoliday, localDate)
        }.collect(Collectors.toList())
    }

}
