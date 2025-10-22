package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.*
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class ScheduleControllerTest : RestDocsTest() {

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Test
    fun `createSchedule test`() {
        // Given
        val member = TestData.member

        val jwt = getJwt(member)
        val updateScheduleDto = ScheduleSaveDto(
            memberId = member.id!!,
            content = "test",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1),
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)
        val sizeBefore = scheduleRepository.findAll().size

        // Then
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/create",
                    requestFields(
                        fieldWithPath("memberId").description("Member Id"),
                        fieldWithPath("content").description("Schedule Content"),
                        fieldWithPath("description").description("Schedule Description"),
                        fieldWithPath("startDateTime").description("Schedule Start DateTime"),
                        fieldWithPath("endDateTime").description("Schedule End DateTime"),
                        fieldWithPath("visibility").description("Schedule Visibility"),
                        fieldWithPath("id").description("Schedule Id (optional, for update)").type("UUID").optional(),
                        fieldWithPath("attachmentSessionId").description("Attachment Session Id (optional)")
                            .type("UUID").optional(),
                        fieldWithPath("orderedAttachmentIds").description("Ordered Attachment Ids (optional)")
                            .type("Array").optional()
                    )
                )
            )
        assertThat(scheduleRepository.findAll().size).isEqualTo(sizeBefore + 1)
    }

    @Test
    fun `createScheduleTest unauthorized`() {
        // Given
        val updateScheduleDto = ScheduleSaveDto(
            memberId = 1234,
            content = "test",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // Then
        mockMvc.perform(
            post("/api/schedules")
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

    @Test
    fun `update schedule test`() {
        // Given
        val member = TestData.member
        val oldSchedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1),
                position = 0,
            )
        )

        val jwt = getJwt(member)
        val updateScheduleDto = ScheduleSaveDto(
            id = oldSchedule.id,
            memberId = member.id!!,
            content = "test2",
            startDateTime = LocalDateTime.now().plusHours(2),
            endDateTime = LocalDateTime.now().plusHours(3)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // Then
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/update",
                    requestFields(
                        fieldWithPath("id").description("Schedule id"),
                        fieldWithPath("memberId").description("Member Id"),
                        fieldWithPath("content").description("Schedule Content"),
                        fieldWithPath("description").description("Schedule Description"),
                        fieldWithPath("startDateTime").description("Schedule Start DateTime"),
                        fieldWithPath("endDateTime").description("Schedule End DateTime"),
                        fieldWithPath("visibility").description("Schedule Visibility"),
                        fieldWithPath("attachmentSessionId").description("Attachment Session Id (optional)")
                            .type("UUID").optional(),
                        fieldWithPath("orderedAttachmentIds").description("Ordered Attachment Ids (optional)")
                            .type("Array").optional()
                    )
                )
            )
        scheduleRepository.findById(oldSchedule.id).orElseThrow().apply {
            assertThat(this.content).isEqualTo(updateScheduleDto.content)
            assertThat(this.startDateTime).isEqualTo(updateScheduleDto.startDateTime)
            assertThat(this.endDateTime).isEqualTo(updateScheduleDto.endDateTime)
        }
    }

    @Test
    fun `swap schedule position test`() {
        // Given
        val member = TestData.member
        val date = LocalDateTime.of(2021, 1, 1, 0, 0)
        val schedule1 = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test",
                startDateTime = date,
                endDateTime = date,
                position = 0
            )
        )
        val schedule2 = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test2",
                startDateTime = date,
                endDateTime = date,
                position = 1
            )
        )
        val jwt = getJwt(member)

        // When
        mockMvc.perform(
            patch("/api/schedules/{id}/position?id2={id2}", schedule1.id, schedule2.id)
                .accept("application/json")
                .contentType("application/json")
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/position",
                    pathParameters(
                        parameterWithName("id").description("Schedule Id1")
                    ),
                    queryParameters(
                        parameterWithName("id2").description("Schedule Id2")
                    )
                )
            )

    }

    @Test
    fun `delete Test`() {
        // Given
        val member = TestData.member
        val oldSchedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1),
                position = 0
            )
        )

        val jwt = getJwt(member)

        // Then
        mockMvc.perform(
            delete("/api/schedules/{id}", oldSchedule.id)
                .accept("application/json")
                .contentType("application/json")
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/delete"
                )
            )

        em.clear()

        assertThat(scheduleRepository.findById(oldSchedule.id)).isEmpty
    }

    @Test
    fun `getSchedules returns schedules with attachments field`() {
        // Given
        val member = TestData.member
        val dateTime = LocalDateTime.of(2024, 3, 10, 0, 0)
        scheduleRepository.save(
            Schedule(
                member = member,
                content = "test schedule",
                startDateTime = dateTime,
                endDateTime = dateTime,
                position = 0
            )
        )

        val jwt = getJwt(member)

        // When & Then
        mockMvc.perform(
            get("/api/schedules")
                .param("memberId", member.id.toString())
                .param("year", "2024")
                .param("month", "3")
                .accept("application/json")
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `update schedule should delete attachments not in orderedAttachmentIds`() {
        // Given
        val member = TestData.member
        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test with attachments",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1),
                position = 0
            )
        )

        val attachment1 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = schedule.id.toString(),
                originalFilename = "test1.jpg",
                storedFilename = "stored1.jpg",
                contentType = "image/jpeg",
                size = 1000L,
                storagePath = "/test/path",
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        val attachment2 = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = schedule.id.toString(),
                originalFilename = "test2.jpg",
                storedFilename = "stored2.jpg",
                contentType = "image/jpeg",
                size = 2000L,
                storagePath = "/test/path",
                createdBy = member.id!!,
                orderIndex = 1
            )
        )

        em.flush()
        em.clear()

        val jwt = getJwt(member)
        val updateScheduleDto = ScheduleSaveDto(
            id = schedule.id,
            memberId = member.id!!,
            content = "updated content",
            startDateTime = LocalDateTime.now().plusHours(2),
            endDateTime = LocalDateTime.now().plusHours(3),
            orderedAttachmentIds = listOf(attachment1.id)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // When
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .cookie(Cookie(jwtConfig.cookieName, jwt))
        ).andExpect(status().isOk)

        em.flush()
        em.clear()

        // Then
        val attachments = attachmentRepository.findAllByContextTypeAndContextId(
            AttachmentContextType.SCHEDULE,
            schedule.id.toString()
        )
        assertThat(attachments).hasSize(1)
        assertThat(attachments[0].id).isEqualTo(attachment1.id)
        assertThat(attachmentRepository.findById(attachment2.id)).isEmpty
    }

}
