package com.tistory.shanepark.dutypark.schedule.timeextract.service

import com.tistory.shanepark.dutypark.TestUtils.Companion.jsr310ObjectMapper
import com.tistory.shanepark.dutypark.schedule.timeextract.domain.ScheduleTimeExtractionRequest
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.Test
import org.springframework.ai.openai.OpenAiChatModel
import org.springframework.ai.openai.OpenAiChatOptions
import org.springframework.ai.openai.api.OpenAiApi
import java.time.LocalDate


class ScheduleTimeExtractionServiceTest {

    @Test
    @Disabled("External API test")
    fun extractScheduleTime() {
        // Given
        val apiKey = "PUT_KEY_HERE_for_external_integration_test"
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

        val service = ScheduleTimeExtractionService(
            chatModel = chatModel,
            objectMapper = jsr310ObjectMapper()
        )


        // Then
        val response = service.extractScheduleTime(
            ScheduleTimeExtractionRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "친구들과 밤 11시에 만나기"
            )
        )

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.dateTime).isEqualTo("2025-02-28T23:00:00")
        Assertions.assertThat(response.content).doesNotContain("11시")

        val response2 = service.extractScheduleTime(
            ScheduleTimeExtractionRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "다섯시 저녁약속"
            )
        )
        Assertions.assertThat(response2.result).isTrue()
        Assertions.assertThat(response2.hasTime).isTrue()
        Assertions.assertThat(response2.dateTime).isEqualTo("2025-02-28T17:00:00")
        Assertions.assertThat(response2.content).doesNotContain("다섯시")

        val response3 = service.extractScheduleTime(
            ScheduleTimeExtractionRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "11:30세탁기설치"
            )
        )
        Assertions.assertThat(response3.result).isTrue()
        Assertions.assertThat(response3.hasTime).isTrue()
        Assertions.assertThat(response3.dateTime).isEqualTo("2025-02-28T11:30:00")
        Assertions.assertThat(response3.content).doesNotContain("11:30")

        val response4 = service.extractScheduleTime(
            ScheduleTimeExtractionRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "오사카 여행"
            )
        )
        Assertions.assertThat(response4.result).isTrue()
        Assertions.assertThat(response4.hasTime).isFalse()
        Assertions.assertThat(response4.dateTime).isNull()
        Assertions.assertThat(response4.content).isEqualTo("오사카 여행")
    }

}
