package com.tistory.shanepark.dutypark.common.datagokr

import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.service.annotation.GetExchange

interface DataGoKrApi {

    @GetExchange("/B090041/openapi/service/SpcdeInfoService/getHoliDeInfo?serviceKey={serviceKey}&solYear={solYear}&numOfRows=100")
    fun getHolidays(
        @PathVariable("serviceKey") serviceKey: String,
        @PathVariable("solYear") year: Int,
    ): String

}
