package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.MethodSource
import org.junit.jupiter.params.provider.Arguments
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime

@AutoConfigureMockMvc
class BusinessFailureSessionPreservationTest : DutyparkIntegrationTest() {
    @Autowired lateinit var mockMvc: MockMvc
    @Autowired lateinit var schedules: ScheduleRepository
    @Autowired lateinit var todos: TodoRepository
    @Autowired lateinit var ddays: DDayRepository
    @Autowired lateinit var sessions: AttachmentUploadSessionRepository

    @ParameterizedTest(name = "{0}, impersonating={1}")
    @MethodSource("businessFailures")
    fun `business rejection preserves an authenticated session`(scenario: String, impersonating: Boolean) {
        val actor = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val other = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        other.calendarVisibility = Visibility.PRIVATE
        other.team = TestData.team2
        val jwt = if (impersonating) getImpersonationJwt(actor, TestData.admin) else getJwt(actor)
        val now = LocalDateTime.of(2025, 1, 15, 12, 0)
        var expectedStatus = 403
        var code: String? = null
        val request = when (scenario) {
            "password-input" -> {
                expectedStatus = if (impersonating) 403 else 400
                code = if (impersonating) "auth.reauth.impersonationForbidden" else "auth.password.currentMismatch"
                put("/api/auth/password").content("""{"memberId":${actor.id},"currentPassword":"wrong-password","newPassword":"new-password"}""")
            }
            "password-owner" -> {
                code = "auth.password.changeUnauthorized"
                put("/api/auth/password").content("""{"memberId":${other.id},"currentPassword":"wrong-password","newPassword":"new-password"}""")
            }
            "member-visibility" -> { code = "member.visibility.forbidden"; get("/api/members/${other.id}") }
            "duty-edit" -> {
                code = "duty.edit.forbidden"
                delete("/api/duty/override").param("memberId", other.id.toString()).param("date", "2025-01-15")
            }
            "dday-owner" -> {
                code = "dday.access.forbidden"
                val dday = ddays.save(DDayEvent(other, "event", LocalDate.of(2025, 1, 15)))
                delete("/api/dday/${dday.id}")
            }
            "schedule-owner" -> {
                code = "schedule.write.forbidden"
                val schedule = schedules.save(Schedule(other, "event", startDateTime = now, endDateTime = now))
                delete("/api/schedules/${schedule.id}")
            }
            "schedule-tag" -> {
                code = "schedule.tag.notFriend"
                val schedule = schedules.save(Schedule(actor, "event", startDateTime = now, endDateTime = now))
                post("/api/schedules/${schedule.id}/tags/${other.id}")
            }
            "todo-tag" -> {
                code = "todo.tag.notFriend"
                val todo = todos.save(Todo(actor, "todo", "", 0))
                post("/api/todos/${todo.id}/tags/${other.id}")
            }
            "team-read" -> {
                code = "team.member.required"
                get("/api/teams/schedules").param("teamId", TestData.team2.id.toString()).param("year", "2025").param("month", "1")
            }
            "team-manage" -> { code = "team.manage.forbidden"; get("/api/teams/manage/${TestData.team2.id}") }
            "team-admin" -> {
                code = "team.admin.required"
                post("/api/teams/manage/${TestData.team.id}/manager").param("memberId", other.id.toString())
            }
            "attachment-session" -> {
                code = "attachment.session.forbidden"
                val session = sessions.save(AttachmentUploadSession(AttachmentContextType.TODO, ownerId = other.id!!, expiresAt = Instant.now().plusSeconds(300)))
                delete("/api/attachments/sessions/${session.id}")
            }
            "token-owner" -> {
                code = "auth.refreshToken.delete.forbidden"
                val session = sessionTokenService.createRefreshToken(other.id!!, "127.0.0.1", "test")
                delete("/api/auth/refresh-tokens/${session.id}")
            }
            "web-push-binding" -> {
                code = "auth.unauthorized"
                post("/api/auth/push/subscribe").content("""{"endpoint":"https://fcm.googleapis.com/token","keys":{"p256dh":"key","auth":"auth"}}""")
            }
            "apns-binding" -> {
                code = "auth.refresh.invalid"
                post("/api/auth/push/apns/register").content("""{"deviceToken":"test-device-token","sandbox":true}""")
            }
            "admin-role" -> get("/admin/api/members")
            else -> error("Unknown scenario: $scenario")
        }
        val result = mockMvc.perform(request.header(HttpHeaders.AUTHORIZATION, "Bearer $jwt").contentType(MediaType.APPLICATION_JSON))
            .andExpect(status().`is`(expectedStatus))
        code?.let { result.andExpect(jsonPath("$.code").value(it)) }
        mockMvc.perform(get("/api/auth/status").header(HttpHeaders.AUTHORIZATION, "Bearer $jwt"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(actor.id))
            .andExpect(jsonPath("$.isImpersonating").value(impersonating))
    }

    @Test
    fun `missing password target is not found without invalidating the admin session`() {
        val jwt = getJwt(TestData.admin)
        mockMvc.perform(put("/api/auth/password")
            .header(HttpHeaders.AUTHORIZATION, "Bearer $jwt")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""{"memberId":9223372036854775807,"currentPassword":"unused","newPassword":"new-password"}"""))
            .andExpect(status().isNotFound)
            .andExpect(jsonPath("$.code").value("auth.password.memberNotFound"))
        mockMvc.perform(get("/api/auth/status").header(HttpHeaders.AUTHORIZATION, "Bearer $jwt"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.admin.id))
    }

    @Test
    fun `revoked authentication still returns unauthorized`() {
        val jwt = getJwt(TestData.member)
        val login = jwtProvider.parseToken(jwt)
        sessionTokenService.deleteRefreshToken(login, requireNotNull(login.sessionId))
        mockMvc.perform(get("/api/members/me").header(HttpHeaders.AUTHORIZATION, "Bearer $jwt"))
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.required"))
    }

    companion object {
        @JvmStatic
        fun businessFailures() = listOf(
            "password-input", "password-owner", "member-visibility", "duty-edit", "dday-owner", "schedule-owner",
            "schedule-tag", "todo-tag", "team-read", "team-manage", "team-admin", "attachment-session",
            "token-owner", "web-push-binding", "apns-binding", "admin-role",
        ).flatMap { scenario -> listOf(false, true).map { Arguments.of(scenario, it) } }
    }
}
