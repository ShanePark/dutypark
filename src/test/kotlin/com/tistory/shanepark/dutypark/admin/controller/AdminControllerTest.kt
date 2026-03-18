package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate
import java.time.LocalDateTime

@AutoConfigureMockMvc
class AdminControllerTest : DutyparkIntegrationTest() {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var todoRepository: TodoRepository

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Autowired
    lateinit var dDayRepository: DDayRepository

    @Autowired
    lateinit var notificationRepository: NotificationRepository

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Test
    fun `non-admin cannot access refresh token list`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/refresh-tokens")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `admin sees only valid refresh tokens`() {
        val validToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        val expiredToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member2.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expiredToken.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expiredToken)
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/refresh-tokens")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].id").value(validToken.id))
    }

    @Test
    fun `admin can search members with keyword and sees valid tokens only`() {
        val validToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        val expiredToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expiredToken.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expiredToken)
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/members")
                .param("keyword", TestData.member.name)
                .param("page", "0")
                .param("size", "10")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].id").value(TestData.member.id))
            .andExpect(jsonPath("$.content[0].name").value(TestData.member.name))
            .andExpect(jsonPath("$.content[0].tokens.length()").value(1))
            .andExpect(jsonPath("$.content[0].tokens[0].id").value(validToken.id))
    }

    @Test
    fun `admin search with unmatched keyword returns empty page`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/members")
                .param("keyword", "no-such-member")
                .param("page", "0")
                .param("size", "10")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(0))
            .andExpect(jsonPath("$.empty").value(true))
    }

    @Test
    fun `admin can fetch member detail with aggregate stats`() {
        val validToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        validToken.subscribePush("https://push.example/${validToken.id}", "p256dh", "auth")
        refreshTokenRepository.save(validToken)

        val expiredToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.2",
            userAgent = "Old-Agent"
        )
        expiredToken.validUntil = fixedDateTime.minusDays(1)
        expiredToken.lastUsed = fixedDateTime.minusDays(2)
        refreshTokenRepository.save(expiredToken)

        scheduleRepository.save(
            Schedule(
                member = TestData.member,
                content = "지난 일정",
                startDateTime = fixedDateTime.minusDays(5),
                endDateTime = fixedDateTime.minusDays(5).plusHours(1),
                position = 0,
            )
        )
        val taggedSchedule = scheduleRepository.save(
            Schedule(
                member = TestData.member2,
                content = "같이 보는 일정",
                startDateTime = fixedDateTime.plusDays(3),
                endDateTime = fixedDateTime.plusDays(3).plusHours(1),
                position = 0,
            )
        )
        taggedSchedule.addTag(TestData.member)
        scheduleRepository.save(taggedSchedule)

        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "비공개 기념일",
                date = LocalDate.now().minusDays(2),
                isPrivate = true,
            )
        )
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "공개 기념일",
                date = LocalDate.now().plusDays(5),
                isPrivate = false,
            )
        )

        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "미완료",
                content = "todo content",
                position = 0,
                status = TodoStatus.TODO,
                dueDate = LocalDate.now().minusDays(1),
            )
        )
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "진행 중",
                content = "todo content",
                position = 1,
                status = TodoStatus.IN_PROGRESS,
                dueDate = LocalDate.now(),
            )
        )
        todoRepository.save(
            Todo(
                member = TestData.member,
                title = "완료",
                content = "todo content",
                position = 2,
                status = TodoStatus.DONE,
                dueDate = LocalDate.now().plusDays(1),
            )
        )

        makeThemFriend(TestData.member, TestData.member2)
        friendRelationRepository.findByMemberAndFriend(TestData.member, TestData.member2)?.isFamily = true
        friendRelationRepository.findByMemberAndFriend(TestData.member2, TestData.member)?.isFamily = true
        makeManagerRelation(manager = TestData.member2, managed = TestData.member)
        makeManagerRelation(manager = TestData.member, managed = TestData.admin)

        friendRequestRepository.save(FriendRequest(fromMember = TestData.admin, toMember = TestData.member))
        friendRequestRepository.save(FriendRequest(fromMember = TestData.member, toMember = TestData.admin))
        memberSocialAccountRepository.save(MemberSocialAccount(TestData.member, SsoType.KAKAO, "kakao-admin-detail"))
        notificationRepository.save(
            Notification(
                member = TestData.member,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                title = "새 친구 요청",
                content = "관리자 테스트",
                referenceType = NotificationReferenceType.MEMBER,
                referenceId = TestData.member2.id.toString(),
                actorId = TestData.admin.id,
            )
        )
        notificationRepository.save(
            Notification(
                member = TestData.member,
                type = NotificationType.FRIEND_REQUEST_ACCEPTED,
                title = "읽은 알림",
                content = "관리자 테스트",
                referenceType = NotificationReferenceType.MEMBER,
                referenceId = TestData.member2.id.toString(),
                actorId = TestData.admin.id,
            ).apply {
                isRead = true
            }
        )

        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/members/{memberId}", TestData.member.id!!)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.member.id))
            .andExpect(jsonPath("$.calendarVisibility").value("FRIENDS"))
            .andExpect(jsonPath("$.serviceAdmin").value(false))
            .andExpect(jsonPath("$.teamAdmin").value(false))
            .andExpect(jsonPath("$.teamManager").value(false))
            .andExpect(jsonPath("$.auxiliaryAccount").value(false))
            .andExpect(jsonPath("$.hasPassword").value(true))
            .andExpect(jsonPath("$.authProviders[0]").value("KAKAO"))
            .andExpect(jsonPath("$.activeSessionCount").value(1))
            .andExpect(jsonPath("$.pushEnabledSessionCount").value(1))
            .andExpect(jsonPath("$.totalScheduleCount").value(1))
            .andExpect(jsonPath("$.upcomingScheduleCount").value(0))
            .andExpect(jsonPath("$.taggedScheduleCount").value(1))
            .andExpect(jsonPath("$.totalTodoCount").value(3))
            .andExpect(jsonPath("$.todoCount").value(1))
            .andExpect(jsonPath("$.inProgressTodoCount").value(1))
            .andExpect(jsonPath("$.doneTodoCount").value(1))
            .andExpect(jsonPath("$.overdueTodoCount").value(1))
            .andExpect(jsonPath("$.dueTodayTodoCount").value(1))
            .andExpect(jsonPath("$.dDays.length()").value(2))
            .andExpect(jsonPath("$.dDays[0].title").value("비공개 기념일"))
            .andExpect(jsonPath("$.dDays[0].isPrivate").value(true))
            .andExpect(jsonPath("$.dDays[1].title").value("공개 기념일"))
            .andExpect(jsonPath("$.dDays[1].isPrivate").value(false))
            .andExpect(jsonPath("$.friendCount").value(1))
            .andExpect(jsonPath("$.familyCount").value(1))
            .andExpect(jsonPath("$.pendingReceivedFriendRequestCount").value(1))
            .andExpect(jsonPath("$.pendingSentFriendRequestCount").value(1))
            .andExpect(jsonPath("$.managerCount").value(1))
            .andExpect(jsonPath("$.managedMemberCount").value(1))
            .andExpect(jsonPath("$.managerNames[0]").value(TestData.member2.name))
            .andExpect(jsonPath("$.managedMemberNames[0]").value(TestData.admin.name))
            .andExpect(jsonPath("$.totalNotificationCount").value(2))
            .andExpect(jsonPath("$.unreadNotificationCount").value(1))
    }
}
