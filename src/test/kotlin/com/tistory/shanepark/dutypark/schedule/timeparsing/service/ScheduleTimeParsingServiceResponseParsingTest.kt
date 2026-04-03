package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.TestUtils.Companion.jsr310JsonMapper
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.ai.chat.messages.AssistantMessage
import org.springframework.ai.chat.model.ChatModel
import org.springframework.ai.chat.model.ChatResponse
import org.springframework.ai.chat.model.Generation
import org.springframework.ai.chat.prompt.Prompt
import java.time.LocalDate

@DisplayName("ScheduleTimeParsingService response parsing")
class ScheduleTimeParsingServiceResponseParsingTest {

    private lateinit var chatModel: ChatModel
    private lateinit var service: ScheduleTimeParsingService

    @BeforeEach
    fun setup() {
        chatModel = mock()
        service = ScheduleTimeParsingService(chatModel, jsr310JsonMapper())
    }

    @Test
    fun `parseScheduleTime extracts final JSON even when thinking text is prepended`() {
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(
                listOf(
                    Generation(
                        AssistantMessage(
                            """
                            <thought>*   Input: `{"date":"2025-02-28","content":"2:50 산본제일 진료"}`
                                *   Task: Extract time from Korean schedule text.
                                *   Output: JSON only.
                            
                                *   Content: "2:50 산본제일 진료"
                                *   Time marker: `2:50` (contains `:`)
                                *   Hour: 2
                                *   Minute: 50
                                *   Date: 2025-02-28
                            
                                *   Rule: "Default hours: 1-6 = PM, 7-11 = AM (but consider activity context)"
                                *   Hour is 2.
                                *   Activity: "산본제일 진료" (Medical treatment/clinic visit).
                                *   Medical clinics usually operate during the day/afternoon, not at 2 AM.
                                *   Therefore, 2:50 should be interpreted as PM (14:50).
                            
                                *   `result`: true (Normal case)
                                *   `hasTime`: true (Time marker `2:50` found)
                                *   `startDateTime`: "2025-02-28T14:50:00"
                                *   `endDateTime`: "2025-02-28T14:50:00" (No range specified)
                                *   `content`: "산본제일 진료" (Strip the time expression "2:50")
                            
                                *   Is it a logical error? No.
                                *   Is it an impossible hour? No.
                                *   Is it multiple times? No.
                                *   Is it a relative time? No.
                            
                            {"result":true,"hasTime":true,"startDateTime":"2025-02-28T14:50:00","endDateTime":"2025-02-28T14:50:00","content":"산본제일 진료"}
                            """.trimIndent()
                        )
                    )
                )
            )
        )

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "2:50 산본제일 진료"
            )
        )

        assertThat(response.result).isTrue()
        assertThat(response.hasTime).isTrue()
        assertThat(response.startDateTime).isEqualTo("2025-02-28T14:50:00")
        assertThat(response.endDateTime).isEqualTo("2025-02-28T14:50:00")
        assertThat(response.content).isEqualTo("산본제일 진료")
    }

    @Test
    fun `parseScheduleTime keeps inline fenced JSON payload`() {
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(
                listOf(
                    Generation(
                        AssistantMessage("""```json {"result":true,"hasTime":true,"startDateTime":"2025-02-28T14:50:00","endDateTime":"2025-02-28T14:50:00","content":"산본제일 진료"} ```""")
                    )
                )
            )
        )

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "2:50 산본제일 진료"
            )
        )

        assertThat(response.result).isTrue()
        assertThat(response.hasTime).isTrue()
        assertThat(response.content).isEqualTo("산본제일 진료")
    }

    @Test
    fun `parseScheduleTime returns failure when generation is empty`() {
        whenever(chatModel.call(any<Prompt>())).thenReturn(ChatResponse(emptyList()))

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "2:50 산본제일 진료"
            )
        )

        assertThat(response.result).isFalse()
        assertThat(response.errorMessage).isEqualTo("LLM API returned empty response")
    }
}
