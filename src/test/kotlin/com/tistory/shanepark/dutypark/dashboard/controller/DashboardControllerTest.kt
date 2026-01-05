package com.tistory.shanepark.dutypark.dashboard.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate
import java.time.LocalDateTime

class DashboardControllerTest : RestDocsTest() {

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `get my dashboard`() {
        val today = LocalDate.now()
        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[0],
                member = TestData.member
            )
        )

        scheduleRepository.save(
            Schedule(
                member = TestData.member,
                content = "Test Schedule",
                description = "Test Description",
                startDateTime = LocalDateTime.now(),
                endDateTime = LocalDateTime.now().plusHours(1),
                position = 0
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/dashboard/my")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.member").exists())
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dashboard/my",
                    responseFields(
                        fieldWithPath("member.id").description("Member ID"),
                        fieldWithPath("member.name").description("Member name"),
                        fieldWithPath("member.email").description("Member email"),
                        fieldWithPath("member.teamId").description("Team ID"),
                        fieldWithPath("member.team").description("Team name"),
                        fieldWithPath("member.calendarVisibility").description("Calendar visibility setting"),
                        fieldWithPath("member.kakaoId").description("Kakao ID (nullable)"),
                        fieldWithPath("member.hasPassword").description("Whether member has password set"),
                        fieldWithPath("member.hasProfilePhoto").description("Whether member has profile photo"),
                        fieldWithPath("duty").description("Today's duty (nullable)"),
                        fieldWithPath("duty.year").description("Duty year").optional(),
                        fieldWithPath("duty.month").description("Duty month").optional(),
                        fieldWithPath("duty.day").description("Duty day").optional(),
                        fieldWithPath("duty.dutyType").description("Duty type name").optional(),
                        fieldWithPath("duty.dutyColor").description("Duty color").optional(),
                        fieldWithPath("duty.isOff").description("Is off day").optional(),
                        fieldWithPath("schedules").description("Today's schedules"),
                        fieldWithPath("schedules[].id").description("Schedule ID"),
                        fieldWithPath("schedules[].content").description("Schedule content"),
                        fieldWithPath("schedules[].description").description("Schedule description"),
                        fieldWithPath("schedules[].position").description("Schedule position"),
                        fieldWithPath("schedules[].year").description("Year"),
                        fieldWithPath("schedules[].month").description("Month"),
                        fieldWithPath("schedules[].dayOfMonth").description("Day of month"),
                        fieldWithPath("schedules[].startDateTime").description("Start date time"),
                        fieldWithPath("schedules[].endDateTime").description("End date time"),
                        fieldWithPath("schedules[].isTagged").description("Is tagged"),
                        fieldWithPath("schedules[].owner").description("Owner name"),
                        fieldWithPath("schedules[].tags").description("Tagged members"),
                        fieldWithPath("schedules[].visibility").description("Visibility"),
                        fieldWithPath("schedules[].dateToCompare").description("Date for comparison"),
                        fieldWithPath("schedules[].attachments").description("Attachments"),
                        fieldWithPath("schedules[].daysFromStart").description("Days from start").optional(),
                        fieldWithPath("schedules[].totalDays").description("Total days").optional(),
                        fieldWithPath("schedules[].startDate").description("Start date"),
                        fieldWithPath("schedules[].endDate").description("End date"),
                        fieldWithPath("schedules[].curDate").description("Current date for display")
                    )
                )
            )
    }

    @Test
    fun `get friends dashboard`() {
        makeThemFriend(TestData.member, TestData.member2)

        val today = LocalDate.now()
        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[1],
                member = TestData.member2
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/dashboard/friends")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.friends").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "dashboard/friends",
                    responseFields(
                        fieldWithPath("friends").description("List of friends with their dashboard info"),
                        fieldWithPath("friends[].member.id").description("Friend member ID"),
                        fieldWithPath("friends[].member.name").description("Friend name"),
                        fieldWithPath("friends[].member.teamId").description("Friend team ID"),
                        fieldWithPath("friends[].member.team").description("Friend team name"),
                        fieldWithPath("friends[].member.hasProfilePhoto").description("Whether friend has profile photo"),
                        fieldWithPath("friends[].duty").description("Friend's today duty (nullable)"),
                        fieldWithPath("friends[].duty.year").description("Duty year").optional(),
                        fieldWithPath("friends[].duty.month").description("Duty month").optional(),
                        fieldWithPath("friends[].duty.day").description("Duty day").optional(),
                        fieldWithPath("friends[].duty.dutyType").description("Duty type").optional(),
                        fieldWithPath("friends[].duty.dutyColor").description("Duty color").optional(),
                        fieldWithPath("friends[].duty.isOff").description("Is off").optional(),
                        fieldWithPath("friends[].schedules").description("Friend's today schedules"),
                        fieldWithPath("friends[].isFamily").description("Is family member"),
                        fieldWithPath("friends[].pinOrder").description("Pin order for sorting"),
                        fieldWithPath("pendingRequestsTo").description("Pending friend requests sent"),
                        fieldWithPath("pendingRequestsFrom").description("Pending friend requests received")
                    )
                )
            )
    }

    @Test
    fun `get my dashboard unauthorized`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/dashboard/my")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
            .andDo(document("dashboard/my-unauthorized"))
    }

}
