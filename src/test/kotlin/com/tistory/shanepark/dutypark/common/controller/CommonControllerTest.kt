package com.tistory.shanepark.dutypark.common.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
class CommonControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Test
    fun `calendar endpoint returns 42 days with correct boundaries`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/calendar")
                .param("year", "2024")
                .param("month", "1")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(42))
            .andExpect(jsonPath("$[0].year").value(2023))
            .andExpect(jsonPath("$[0].month").value(12))
            .andExpect(jsonPath("$[0].day").value(31))
            .andExpect(jsonPath("$[41].year").value(2024))
            .andExpect(jsonPath("$[41].month").value(2))
            .andExpect(jsonPath("$[41].day").value(10))
    }

    @Test
    fun `calendar endpoint returns bad request for invalid month`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/calendar")
                .param("year", "2024")
                .param("month", "13")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("common.badRequest"))
    }
}
