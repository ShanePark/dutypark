package com.tistory.shanepark.dutypark.holiday.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.common.datagokr.DataGoKrApi
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPIDataGoKr
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPIDataGoKrTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.kotlin.any
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.get
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.request.RequestDocumentation
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.test.util.ReflectionTestUtils
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class HolidayControllerTest : RestDocsTest() {

    @Autowired
    private lateinit var holidayService: HolidayService

    @Mock
    private lateinit var dataGoKrApi: DataGoKrApi

    /**
     * Mocking External API
     */
    @BeforeEach
    fun setup() {
        Mockito.`when`(dataGoKrApi.getHolidays(any(), any())).thenReturn(HolidayAPIDataGoKrTest.apiResponse2023)
        val holidayAPIDataGoKr = HolidayAPIDataGoKr(dataGoKrApi)
        HolidayAPIDataGoKr::class.java.getDeclaredField("serviceKey").apply {
            isAccessible = true
            set(holidayAPIDataGoKr, "SERVICE_KEY_HERE")
        }
        ReflectionTestUtils.setField(holidayService, "holidayAPI", holidayAPIDataGoKr)
    }

    @Test
    fun getHolidays() {
        mockMvc.perform(
            get("/api/holiday")
                .accept("application/json")
                .param("year", "2023")
                .param("month", "5")
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "holiday/get",
                    RequestDocumentation.queryParameters(
                        parameterWithName("year").description("Year"),
                        parameterWithName("month").description("Month")
                    ),
                    responseFields(
                        fieldWithPath("[]").description("Days of the requested calendar month"),
                        fieldWithPath("[].[]").description("Holiday List"),
                        fieldWithPath("[].[].dateName").description("Holiday Name"),
                        fieldWithPath("[].[].isHoliday").description("Is it a Holiday"),
                        fieldWithPath("[].[].localDate").description("Holiday Date")
                    )
                )
            )
    }

}
