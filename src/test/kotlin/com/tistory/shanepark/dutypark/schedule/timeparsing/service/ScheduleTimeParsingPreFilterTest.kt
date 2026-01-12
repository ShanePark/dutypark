package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.TestUtils.Companion.jsr310JsonMapper
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.mockito.Mockito.*
import org.springframework.ai.chat.model.ChatModel
import java.time.LocalDate

@DisplayName("ScheduleTimeParsingService Pre-filter Tests")
class ScheduleTimeParsingPreFilterTest {

    private lateinit var chatModel: ChatModel
    private lateinit var service: ScheduleTimeParsingService

    @BeforeEach
    fun setup() {
        chatModel = mock(ChatModel::class.java)
        service = ScheduleTimeParsingService(chatModel, jsr310JsonMapper())
    }

    @Nested
    @DisplayName("Cases that should skip LLM (no time indicators)")
    inner class SkipLlmCases {

        @ParameterizedTest
        @DisplayName("Basic schedules without any numbers")
        @ValueSource(
            strings = [
                "주말 데이트",
                "오사카 여행",
                "엄마랑 점심",
                "저녁 약속",
                "친구 만나기",
                "영화 보기",
                "책 읽기",
                "산책",
                "운동",
                "회의 참석",
            ]
        )
        fun `basic schedules without numbers should skip LLM`(content: String) {
            val response = parseAndAssertSkipped(content)
            assertThat(response.content).isEqualTo(content)
        }

        @ParameterizedTest
        @DisplayName("Period-only expressions without specific time")
        @ValueSource(
            strings = [
                "새벽 미팅",
                "오전 중으로 처리",
                "오후에 전화",
                "저녁때 만나요",
                "밤에 연락",
                "아침 조깅",
            ]
        )
        fun `period words without numbers should skip LLM`(content: String) {
            val response = parseAndAssertSkipped(content)
            assertThat(response.content).isEqualTo(content)
        }

        @ParameterizedTest
        @DisplayName("Special characters and symbols")
        @ValueSource(
            strings = [
                "미팅 @카페",
                "약속!!",
                "중요!!!",
                "메모 - 장보기",
                "계획 (미정)",
            ]
        )
        fun `special characters without numbers should skip LLM`(content: String) {
            val response = parseAndAssertSkipped(content)
            assertThat(response.content).isEqualTo(content)
        }

        @ParameterizedTest
        @DisplayName("English text without numbers")
        @ValueSource(
            strings = [
                "Meeting",
                "Coffee break",
                "Team lunch",
                "Project review",
            ]
        )
        fun `english text without numbers should skip LLM`(content: String) {
            val response = parseAndAssertSkipped(content)
            assertThat(response.content).isEqualTo(content)
        }

        @Test
        @DisplayName("Empty or whitespace content")
        fun `empty or whitespace should skip LLM`() {
            val emptyResponse = parseAndAssertSkipped("")
            assertThat(emptyResponse.content).isEqualTo("")

            val whitespaceResponse = parseAndAssertSkipped("   ")
            assertThat(whitespaceResponse.content).isEqualTo("   ")
        }

        @ParameterizedTest
        @DisplayName("Similar-looking but not time-related Korean words")
        @ValueSource(
            strings = [
                "여행 계획",
                "여름 휴가",
                "여자친구 만남",
                "다음 주",
                "다른 일정",
            ]
        )
        fun `korean words that look similar to time numbers should skip LLM`(content: String) {
            val response = parseAndAssertSkipped(content)
            assertThat(response.content).isEqualTo(content)
        }

        private fun parseAndAssertSkipped(content: String): ScheduleTimeParsingResponse {
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = content
            )

            val response = service.parseScheduleTime(request)

            assertThat(response.result).isTrue()
            assertThat(response.hasTime).isFalse()
            return response
        }
    }

    @Nested
    @DisplayName("Cases that should call LLM (time indicators present)")
    inner class CallLlmCases {

        @ParameterizedTest
        @DisplayName("Arabic numerals 0-9")
        @ValueSource(
            strings = [
                "0시 자정",
                "1시 약속",
                "2시 미팅",
                "3시 회의",
                "4시 커피",
                "5시 퇴근",
                "6시 저녁",
                "7시 운동",
                "8시 아침",
                "9시 출근",
            ]
        )
        fun `arabic numerals should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        @ParameterizedTest
        @DisplayName("Korean number words for hours")
        @ValueSource(
            strings = [
                "한시에 만나자",
                "두시 반",
                "세시쯤",
                "네시 출발",
                "다섯시 저녁",
                "여섯시 약속",
                "일곱시 기상",
                "여덟시 아침",
                "아홉시 출근",
                "열시 회의",
            ]
        )
        fun `korean number words should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        @ParameterizedTest
        @DisplayName("Compound Korean numbers (11, 12)")
        @ValueSource(
            strings = [
                "열한시 브런치",
                "열두시 점심",
            ]
        )
        fun `compound korean numbers should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        @ParameterizedTest
        @DisplayName("Special time words")
        @ValueSource(
            strings = [
                "정오에 점심",
                "자정까지 작업",
                "정오 미팅",
                "자정 넘어서",
            ]
        )
        fun `special time words should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        @ParameterizedTest
        @DisplayName("Time with colon format")
        @ValueSource(
            strings = [
                "10:30 회의",
                "14:00 미팅",
                "9:00 출근",
                "18:30 저녁약속",
            ]
        )
        fun `colon time format should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        @ParameterizedTest
        @DisplayName("Numbers in various positions")
        @ValueSource(
            strings = [
                "3시 미팅",
                "미팅 3시",
                "오후 3시 미팅",
                "미팅 오후 3시에",
            ]
        )
        fun `numbers in various positions should trigger LLM`(content: String) {
            assertLlmCalled(content)
        }

        private fun assertLlmCalled(content: String) {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = content
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }
    }

    @Nested
    @DisplayName("False positive cases (numbers present but not time-related)")
    inner class FalsePositiveCases {

        @ParameterizedTest
        @DisplayName("Numbers that are not time should still trigger LLM (acceptable false positive)")
        @ValueSource(
            strings = [
                "3층 카페",
                "5명이서 모임",
                "2번 출구",
                "15일 약속",
                "1호선 타기",
                "3개 구매",
                "제2회의실",
            ]
        )
        fun `non-time numbers trigger LLM which is acceptable`(content: String) {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = content
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }

        @ParameterizedTest
        @DisplayName("Korean words containing time-number characters")
        @ValueSource(
            strings = [
                "한국 여행",
                "두부 요리",
                "세수하기",
                "네모 그리기",
                "열쇠 찾기",
            ]
        )
        fun `korean words with time-like characters trigger LLM which is acceptable`(content: String) {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = content
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }
    }

    @Nested
    @DisplayName("Edge cases and boundary conditions")
    inner class EdgeCases {

        @Test
        @DisplayName("Mixed content with time indicator at the end")
        fun `time indicator at end should trigger LLM`() {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = "약속 3"
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }

        @Test
        @DisplayName("Single digit should trigger LLM")
        fun `single digit should trigger LLM`() {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = "7"
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }

        @Test
        @DisplayName("Single Korean time word should trigger LLM")
        fun `single korean time word should trigger LLM`() {
            reset(chatModel)
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = "정오"
            )

            service.parseScheduleTime(request)

            verify(chatModel).call(any(org.springframework.ai.chat.prompt.Prompt::class.java))
        }

        @Test
        @DisplayName("Long text without any time indicators")
        fun `long text without time indicators should skip LLM`() {
            val longContent = "오늘은 친구들과 함께 맛있는 음식을 먹으러 가기로 했어요. " +
                    "어디로 갈지는 아직 정하지 않았지만 분위기 좋은 곳으로 가고 싶어요."

            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = longContent
            )

            val response = service.parseScheduleTime(request)

            assertThat(response.result).isTrue()
            assertThat(response.hasTime).isFalse()
            assertThat(response.content).isEqualTo(longContent)
        }

        @Test
        @DisplayName("Fullwidth unicode numbers are not supported and skip LLM")
        fun `fullwidth unicode numbers skip LLM as not supported`() {
            val request = ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 1, 15),
                content = "３시 미팅"
            )

            val response = service.parseScheduleTime(request)

            assertThat(response.result).isTrue()
            assertThat(response.hasTime).isFalse()
        }
    }

}
