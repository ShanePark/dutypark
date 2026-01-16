package com.tistory.shanepark.dutypark.schedule.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.hamcrest.Matchers.hasItem
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.*
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.content
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.http.MediaType
import java.time.LocalDateTime

class ScheduleControllerTest : RestDocsTest() {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

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
            startDateTime = fixedDateTime,
            endDateTime = fixedDateTime.plusHours(1),
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)
        val sizeBefore = scheduleRepository.findAll().size

        // Then
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
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
            startDateTime = fixedDateTime,
            endDateTime = fixedDateTime.plusHours(1)
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
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0,
            )
        )

        val jwt = getJwt(member)
        val updateScheduleDto = ScheduleSaveDto(
            id = oldSchedule.id,
            memberId = member.id!!,
            content = "test2",
            startDateTime = fixedDateTime.plusHours(2),
            endDateTime = fixedDateTime.plusHours(3)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // Then
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
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
    fun `delete Test`() {
        // Given
        val member = TestData.member
        val oldSchedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "test",
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0
            )
        )

        val jwt = getJwt(member)

        // Then
        mockMvc.perform(
            delete("/api/schedules/{id}", oldSchedule.id)
                .accept("application/json")
                .contentType("application/json")
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "schedules/delete"
                )
            )

        em.clear()

        assertThat(scheduleRepository.findById(oldSchedule.id)).isEmpty()
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
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$..content").value(hasItem("test schedule")))
            .andExpect(jsonPath("$..attachments").exists())
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
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
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
            startDateTime = fixedDateTime.plusHours(2),
            endDateTime = fixedDateTime.plusHours(3),
            orderedAttachmentIds = listOf(attachment1.id)
        )
        val json = objectMapper.writeValueAsString(updateScheduleDto)

        // When
        mockMvc.perform(
            post("/api/schedules")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
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
        assertThat(attachmentRepository.findById(attachment2.id)).isEmpty()
    }

    @Test
    fun `getSchedules returns empty when not visible`() {
        val member = TestData.member
        val other = TestData.member2
        scheduleRepository.save(
            Schedule(
                member = member,
                content = "private schedule",
                startDateTime = LocalDateTime.of(2024, 3, 1, 0, 0),
                endDateTime = LocalDateTime.of(2024, 3, 1, 1, 0),
                position = 0
            )
        )

        mockMvc.perform(
            get("/api/schedules")
                .param("memberId", member.id.toString())
                .param("year", "2024")
                .param("month", "3")
                .accept("application/json")
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(other)}")
        ).andExpect(status().isOk)
            .andExpect(content().json("[]"))
    }

    @Test
    fun `getSchedule returns basic info`() {
        val member = TestData.member
        val schedule = scheduleRepository.save(
            Schedule(
                member = member,
                content = "detail",
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0
            )
        )

        mockMvc.perform(
            get("/api/schedules/{id}", schedule.id)
                .accept("application/json")
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(schedule.id.toString()))
            .andExpect(jsonPath("$.memberId").value(member.id!!.toInt()))
            .andExpect(jsonPath("$.content").value("detail"))
    }

    @Test
    fun `searchSchedule returns results`() {
        val member = TestData.member
        scheduleRepository.save(
            Schedule(
                member = member,
                content = "team sync",
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0
            )
        )

        mockMvc.perform(
            get("/api/schedules/{id}/search", member.id!!)
                .param("q", "team")
                .accept("application/json")
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.content[0].content").value("team sync"))
    }

    @Test
    fun `tag and untag friend endpoints`() {
        val owner = TestData.member
        val friend = TestData.member2
        makeThemFriend(owner, friend)

        val schedule = scheduleRepository.save(
            Schedule(
                member = owner,
                content = "tagged",
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0
            )
        )

        mockMvc.perform(
            post("/api/schedules/{scheduleId}/tags/{friendId}", schedule.id, friend.id!!)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(owner)}")
        ).andExpect(status().isOk)

        em.flush()
        em.clear()
        val taggedSchedule = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(taggedSchedule.tags).hasSize(1)

        mockMvc.perform(
            delete("/api/schedules/{scheduleId}/tags/{friendId}", schedule.id, friend.id!!)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(owner)}")
        ).andExpect(status().isOk)

        em.flush()
        em.clear()
        val untaggedSchedule = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(untaggedSchedule.tags).isEmpty()
    }

    @Test
    fun `untagSelf removes own tag`() {
        val owner = TestData.member
        val friend = TestData.member2
        makeThemFriend(owner, friend)

        val schedule = scheduleRepository.save(
            Schedule(
                member = owner,
                content = "tagged",
                startDateTime = fixedDateTime,
                endDateTime = fixedDateTime.plusHours(1),
                position = 0
            )
        )
        schedule.addTag(friend)
        scheduleRepository.save(schedule)
        em.flush()
        em.clear()

        mockMvc.perform(
            delete("/api/schedules/{scheduleId}/tags", schedule.id)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(friend)}")
        ).andExpect(status().isOk)

        em.flush()
        em.clear()
        val refreshed = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(refreshed.tags).isEmpty()
    }

    @Test
    fun `reorderSchedulePositions updates order`() {
        val member = TestData.member
        val baseTime = LocalDateTime.of(2024, 1, 1, 0, 0)
        val schedule1 = scheduleRepository.save(
            Schedule(
                member = member,
                content = "first",
                startDateTime = baseTime,
                endDateTime = baseTime.plusHours(1),
                position = 0
            )
        )
        val schedule2 = scheduleRepository.save(
            Schedule(
                member = member,
                content = "second",
                startDateTime = baseTime,
                endDateTime = baseTime.plusHours(1),
                position = 1
            )
        )

        val payload = objectMapper.writeValueAsString(listOf(schedule2.id, schedule1.id))

        mockMvc.perform(
            patch("/api/schedules/positions")
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        ).andExpect(status().isOk)
            .andDo(
                document(
                    "schedules/positions",
                    requestFields(
                        fieldWithPath("[]").description("Ordered schedule ids")
                    )
                )
            )

        em.flush()
        em.clear()
        val updatedFirst = scheduleRepository.findById(schedule1.id).orElseThrow()
        val updatedSecond = scheduleRepository.findById(schedule2.id).orElseThrow()
        assertThat(updatedFirst.position).isEqualTo(1)
        assertThat(updatedSecond.position).isEqualTo(0)
    }

}
