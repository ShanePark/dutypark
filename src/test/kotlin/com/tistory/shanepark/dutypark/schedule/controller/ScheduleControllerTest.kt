package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class ScheduleControllerTest : RestDocsTest() {

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `createScheduleTest`() {
        // Given
        val member = TestData.member

        val jwt = getJwt(member)
        val updateScheduleDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "test",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)
        val sizeBefore = scheduleRepository.findAll().size

        // Then
        mockMvc!!.perform(
            MockMvcRequestBuilders.post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie("SESSION", jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/create",
                    requestFields(
                        fieldWithPath("memberId").description("Member Id"),
                        fieldWithPath("content").description("Schedule Content"),
                        fieldWithPath("startDateTime").description("Schedule Start DateTime"),
                        fieldWithPath("endDateTime").description("Schedule End DateTime")
                    )
                )
            )
        assertThat(scheduleRepository.findAll().size).isEqualTo(sizeBefore + 1)
    }

    @Test
    fun `createScheduleTest_unauthorized`() {
        // Given
        val updateScheduleDto = ScheduleUpdateDto(
            memberId = 1234,
            content = "test",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // Then
        mockMvc!!.perform(
            MockMvcRequestBuilders.post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/create-unauthorized", responseFields(
                        fieldWithPath("errorCode").description("401"),
                        fieldWithPath("message").description("Error Message")
                    )
                )
            )
    }

}
