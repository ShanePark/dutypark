package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.TestUtils.Companion.jsr310ObjectMapper
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.Test
import org.springframework.ai.openai.OpenAiChatModel
import org.springframework.ai.openai.OpenAiChatOptions
import org.springframework.ai.openai.api.OpenAiApi
import java.time.LocalDate

@Disabled("External API test")
class ScheduleTimeParsingServiceTest {

    private val apiKey = "PUT_KEY_HERE_for_external_integration_test"
    val service = makeService()

    private fun makeService(): ScheduleTimeParsingService {
        val openapi = OpenAiApi
            .builder()
            .apiKey(apiKey)
            .baseUrl("https://generativelanguage.googleapis.com/v1beta/openai/")
            .completionsPath("/chat/completions")
            .build()

        val chatOption = OpenAiChatOptions
            .builder()
            .model("gemini-2.0-flash-lite")
            .temperature(0.0)
            .build()

        val chatModel = OpenAiChatModel
            .builder()
            .openAiApi(openapi)
            .defaultOptions(chatOption)
            .build()

        val service = ScheduleTimeParsingService(
            chatModel = chatModel,
            objectMapper = jsr310ObjectMapper()
        )
        return service
    }

    @Test
    fun `parseScheduleTime guess afternoon without mention`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "2:50 산본제일 진료"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T14:50:00")
    }

    @Test
    fun `parseScheduleTime guess night`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "친구들과 밤 11시에 만나기"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T23:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T23:00:00")
        Assertions.assertThat(response.content).doesNotContain("11시")
    }

    @Test
    fun `parseScheduleTime guess evening`() {
        val service = makeService()
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "다섯시 저녁약속"
            )
        )
        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T17:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T17:00:00")
        Assertions.assertThat(response.content).doesNotContain("다섯시")
    }

    @Test
    fun `parseScheduleTime guess AM`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "11:30세탁기설치"
            )
        )
        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T11:30:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T11:30:00")
        Assertions.assertThat(response.content).doesNotContain("11:30")
    }

    @Test
    fun `parseScheduleTime does not have time info`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "오사카 여행"
            )
        )
        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
        Assertions.assertThat(response.startDateTime).isNull()
        Assertions.assertThat(response.endDateTime).isNull()
        Assertions.assertThat(response.content).isEqualTo("오사카 여행")
    }

    @Test
    fun `parseScheduleTime range`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "테니스 2시~4시"
            )
        )
        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T14:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T16:00:00")
        Assertions.assertThat(response.content).doesNotContain("2시")
        Assertions.assertThat(response.content).doesNotContain("4시")
    }

    @Test
    fun `parseScheduleTime guess early morning`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "등산 6시 출발"
            )
        )
        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T06:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T06:00:00")
        Assertions.assertThat(response.content).doesNotContain("5시")
    }

    @Test
    fun `parseScheduleTime have too many time`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "3시 4시 5시중에 대충 밥 먹자"
            )
        )
        Assertions.assertThat(response.result).isFalse()
        Assertions.assertThat(response.hasTime).isFalse()
        Assertions.assertThat(response.startDateTime).isNull()
        Assertions.assertThat(response.endDateTime).isNull()
        Assertions.assertThat(response.content).isNull()
    }

    @Test
    fun `do not assume time`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "오전 검강검진 강남 하나로"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
    }

    @Test
    fun `parseScheduleTime ignore numbers that are not time`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "3개의 보고서 검토 필요"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
        Assertions.assertThat(response.content).isEqualTo("3개의 보고서 검토 필요")
    }

    @Test
    fun `parseScheduleTime handle concatenated time`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "운동 8시30분 시작"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T08:30:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T08:30:00")
        Assertions.assertThat(response.content).doesNotContain("8시30분")
    }

    @Test
    fun `parseScheduleTime ignore relative time`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "조금 뒤에 미팅"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
        Assertions.assertThat(response.content).isEqualTo("조금 뒤에 미팅")
    }

    @Test
    fun `parseScheduleTime invalid time format`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "약속 오후 25시"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
    }

    @Test
    fun `parseScheduleTime invalid time range`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "회의 18시~10시"
            )
        )

        Assertions.assertThat(response.result).isFalse()
    }

    @Test
    fun `parseScheduleTime noon and midnight`() {
        val response1 = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "정오에 점심 먹자"
            )
        )

        Assertions.assertThat(response1.result).isTrue()
        Assertions.assertThat(response1.hasTime).isTrue()
        Assertions.assertThat(response1.startDateTime).isEqualTo("2025-02-28T12:00:00")
        Assertions.assertThat(response1.endDateTime).isEqualTo("2025-02-28T12:00:00")
        Assertions.assertThat(response1.content).doesNotContain("정오")

        val response2 = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "자정에 국지도발훈련"
            )
        )

        Assertions.assertThat(response2.result).isTrue()
        Assertions.assertThat(response2.hasTime).isTrue()
        Assertions.assertThat(response2.startDateTime).isEqualTo("2025-02-28T00:00:00")
        Assertions.assertThat(response2.endDateTime).isEqualTo("2025-02-28T00:00:00")
        Assertions.assertThat(response2.content).doesNotContain("자정")
    }

    @Test
    fun `parseScheduleTime invalid AM PM usage`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "오전 15시 미팅"
            )
        )

        Assertions.assertThat(response.result).isFalse()
    }

    @Test
    fun `parseScheduleTime approximate times`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "대략 3시쯤 만날 예정"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T15:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T15:00:00")
        Assertions.assertThat(response.content).doesNotContain("3시")
    }

    @Test
    fun `parseScheduleTime extract time from long sentence`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "내일은 바쁜 일정이 있어서 오전 10시에 잠깐 미팅을 하고 이후에는 자유시간을 가질 예정입니다."
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.startDateTime).isEqualTo("2025-02-28T10:00:00")
        Assertions.assertThat(response.endDateTime).isEqualTo("2025-02-28T10:00:00")
        Assertions.assertThat(response.content).doesNotContain("10시")
    }

    @Test
    fun `parseScheduleTime only period of day`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "새벽 미팅"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isFalse()
    }

    @Test
    fun `parseScheduleTime multiple distinct times`() {
        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "오전 10시와 오후 3시에 회의"
            )
        )

        Assertions.assertThat(response.result).isFalse()
    }

}
