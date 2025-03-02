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

        val request = ScheduleTimeExtractionRequest(
            date = LocalDate.of(2025, 2, 28),
            content = "친구들과 밤 11시에 만나기"
        )
        val response = service.extractScheduleTime(request)

        Assertions.assertThat(response.result).isTrue()
        Assertions.assertThat(response.hasTime).isTrue()
        Assertions.assertThat(response.dateTime).isEqualTo("2025-02-28T23:00:00")
        Assertions.assertThat(response.content).doesNotContain("11시")
    }


}
