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

}
