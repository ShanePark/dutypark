package com.tistory.shanepark.dutypark.common.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import org.junit.jupiter.api.Test
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.web.servlet.request.AbstractMockHttpServletRequestBuilder
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class CalendarRequestDateValidationTest : RestDocsTest() {

    private val invalidYearMonths = listOf(
        2000000000 to 6,
        0 to 6,
        -1 to 6,
        1 to 1,
        9999 to 6,
        2026 to 0,
        2026 to 13,
        2026 to -1,
    )

    private val boundaryYearMonths = listOf(2 to 1, 9998 to 12)

    @Test
    fun `holidays rejects year or month that cannot form a calendar`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(get("/api/holidays").yearMonth(year, month))
        }
    }

    @Test
    fun `holidays keeps returning an empty calendar for a far but valid year`() {
        (listOf(1500 to 6) + boundaryYearMonths).forEach { (year, month) ->
            mockMvc.perform(get("/api/holidays").yearMonth(year, month))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.length()").value(42))
                .andExpect(jsonPath("$[*][*]").isEmpty)
        }
    }

    @Test
    fun `calendar rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(get("/api/calendar").yearMonth(year, month))
        }
    }

    @Test
    fun `calendar accepts boundary years`() {
        boundaryYearMonths.forEach { (year, month) ->
            mockMvc.perform(get("/api/calendar").yearMonth(year, month))
                .andExpect(status().isOk)
                .andExpect(jsonPath("$.length()").value(42))
        }
    }

    @Test
    fun `duty rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                get("/api/duty").yearMonth(year, month)
                    .param("memberId", TestData.member.id!!.toString())
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `duty accepts boundary years`() {
        boundaryYearMonths.forEach { (year, month) ->
            mockMvc.perform(
                get("/api/duty").yearMonth(year, month)
                    .param("memberId", TestData.member.id!!.toString())
                    .withAuth(TestData.member)
            ).andExpect(status().isOk)
                .andExpect(jsonPath("$.length()").value(42))
        }
    }

    @Test
    fun `other duties rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                get("/api/duty/others").yearMonth(year, month)
                    .param("memberIds", TestData.member.id!!.toString())
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `duty change rejects a date that does not exist`() {
        listOf(Triple(2000000000, 6, 1), Triple(2026, 13, 1), Triple(2026, 2, 30), Triple(2026, 6, 0)).forEach { (year, month, day) ->
            expectBadRequest(
                put("/api/duty/change")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        """{"year":$year,"month":$month,"day":$day,"dutyTypeId":null,"memberId":${TestData.member.id}}"""
                    )
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `duty batch upload rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                multipart("/api/duty_batch")
                    .file(dummyFile())
                    .param("memberId", TestData.member.id!!.toString())
                    .param("year", year.toString())
                    .param("month", month.toString())
                    .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
            )
        }
    }

    @Test
    fun `schedules rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                get("/api/schedules").yearMonth(year, month)
                    .param("memberId", TestData.member.id!!.toString())
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `schedules accepts boundary years`() {
        boundaryYearMonths.forEach { (year, month) ->
            mockMvc.perform(
                get("/api/schedules").yearMonth(year, month)
                    .param("memberId", TestData.member.id!!.toString())
                    .withAuth(TestData.member)
            ).andExpect(status().isOk)
                .andExpect(jsonPath("$.length()").value(42))
        }
    }

    @Test
    fun `todo calendar rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(get("/api/todos/calendar").yearMonth(year, month).withAuth(TestData.member))
        }
    }

    @Test
    fun `my team summary rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(get("/api/teams/my").yearMonth(year, month).withAuth(TestData.member))
        }
    }

    @Test
    fun `team shift rejects a date that does not exist`() {
        listOf(Triple(2000000000, 6, 1), Triple(2026, 13, 1), Triple(2026, 2, 30), Triple(2026, 6, 0)).forEach { (year, month, day) ->
            expectBadRequest(
                get("/api/teams/shift").yearMonth(year, month)
                    .param("day", day.toString())
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `team schedules rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                get("/api/teams/schedules").yearMonth(year, month)
                    .param("teamId", TestData.team.id!!.toString())
                    .withAuth(TestData.member)
            )
        }
    }

    @Test
    fun `team duty batch upload rejects invalid year or month`() {
        invalidYearMonths.forEach { (year, month) ->
            expectBadRequest(
                multipart("/api/teams/manage/{teamId}/duty", TestData.team.id!!)
                    .file(dummyFile())
                    .param("year", year.toString())
                    .param("month", month.toString())
                    .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
            )
        }
    }

    private fun MockHttpServletRequestBuilder.yearMonth(year: Int, month: Int): MockHttpServletRequestBuilder =
        param("year", year.toString()).param("month", month.toString())

    private fun expectBadRequest(request: AbstractMockHttpServletRequestBuilder<*>) {
        mockMvc.perform(request.accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.code").value("common.badRequest"))
    }

    private fun dummyFile() = MockMultipartFile(
        "file",
        "duty.xlsx",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "dummy".toByteArray(),
    )
}
