package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.payload.PayloadDocumentation.subsectionWithPath
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

class AdminControllerDocsTest : RestDocsTest() {

    @Autowired
    lateinit var dDayRepository: DDayRepository

    @Test
    fun `admin member detail`() {
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "결혼 기념일",
                date = LocalDate.now().plusDays(10),
                isPrivate = false,
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/members/{memberId}", TestData.member.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/members-detail",
                    pathParameters(
                        parameterWithName("memberId").description("상세 조회할 회원 ID")
                    ),
                    responseFields(
                        fieldWithPath("id").description("회원 ID"),
                        fieldWithPath("name").description("회원 이름"),
                        fieldWithPath("email").description("이메일").optional(),
                        fieldWithPath("teamId").description("소속 팀 ID").optional(),
                        fieldWithPath("teamName").description("소속 팀 이름").optional(),
                        fieldWithPath("calendarVisibility").description("캘린더 공개 범위"),
                        fieldWithPath("hasProfilePhoto").description("프로필 사진 보유 여부"),
                        fieldWithPath("profilePhotoVersion").description("프로필 사진 버전"),
                        fieldWithPath("serviceAdmin").description("서비스 관리자 여부"),
                        fieldWithPath("teamAdmin").description("팀장 여부"),
                        fieldWithPath("teamManager").description("팀 매니저 여부"),
                        fieldWithPath("auxiliaryAccount").description("보조 계정 여부"),
                        fieldWithPath("hasPassword").description("비밀번호 로그인 가능 여부"),
                        subsectionWithPath("authProviders").description("연결된 소셜 로그인 제공자 목록"),
                        fieldWithPath("createdDate").description("가입 일시"),
                        fieldWithPath("lastModifiedDate").description("최근 수정 일시"),
                        fieldWithPath("activeSessionCount").description("현재 유효한 세션 수"),
                        fieldWithPath("pushEnabledSessionCount").description("푸시 구독이 연결된 세션 수"),
                        fieldWithPath("lastActiveAt").description("최근 세션 활동 시각").optional(),
                        fieldWithPath("totalScheduleCount").description("직접 등록한 일정 수"),
                        fieldWithPath("upcomingScheduleCount").description("종료되지 않은 일정 수"),
                        fieldWithPath("taggedScheduleCount").description("태그된 일정 수"),
                        fieldWithPath("totalTodoCount").description("전체 TODO 수"),
                        fieldWithPath("todoCount").description("대기 상태 TODO 수"),
                        fieldWithPath("inProgressTodoCount").description("진행 중 TODO 수"),
                        fieldWithPath("doneTodoCount").description("완료 TODO 수"),
                        fieldWithPath("overdueTodoCount").description("기한 지난 미완료 TODO 수"),
                        fieldWithPath("dueTodayTodoCount").description("오늘 마감인 미완료 TODO 수"),
                        fieldWithPath("dDays").description("회원 D-Day 목록"),
                        fieldWithPath("dDays[].id").description("D-Day ID"),
                        fieldWithPath("dDays[].title").description("D-Day 제목"),
                        fieldWithPath("dDays[].date").description("D-Day 날짜"),
                        fieldWithPath("dDays[].isPrivate").description("비공개 여부"),
                        fieldWithPath("dDays[].calc").description("한국식 D-Day 계산값(당일 0, 지난 날짜는 음수 이전 값)"),
                        fieldWithPath("dDays[].daysLeft").description("오늘 기준 남은 일 수"),
                        fieldWithPath("friendCount").description("친구 수"),
                        fieldWithPath("familyCount").description("가족 표시된 친구 수"),
                        fieldWithPath("pendingReceivedFriendRequestCount").description("받은 대기 중 친구 요청 수"),
                        fieldWithPath("pendingSentFriendRequestCount").description("보낸 대기 중 친구 요청 수"),
                        fieldWithPath("managerCount").description("이 회원을 관리하는 계정 수"),
                        fieldWithPath("managedMemberCount").description("이 회원이 관리하는 계정 수"),
                        subsectionWithPath("managerNames").description("이 회원을 관리하는 계정 이름 목록"),
                        subsectionWithPath("managedMemberNames").description("이 회원이 관리하는 계정 이름 목록"),
                        fieldWithPath("totalNotificationCount").description("전체 알림 수"),
                        fieldWithPath("unreadNotificationCount").description("읽지 않은 알림 수"),
                    )
                )
            )
    }
}
