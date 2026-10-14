package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.TestUtils.Companion.jsr310JsonMapper
import com.tistory.shanepark.dutypark.common.config.AiProperties
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.ai.chat.messages.AssistantMessage
import org.springframework.ai.chat.model.ChatModel
import org.springframework.ai.chat.model.ChatResponse
import org.springframework.ai.chat.model.Generation
import org.springframework.ai.chat.prompt.Prompt
import org.springframework.ai.openai.OpenAiChatOptions
import java.time.LocalDate
import java.time.Duration
import java.util.concurrent.atomic.AtomicReference

@DisplayName("ScheduleTimeParsingService response parsing")
class ScheduleTimeParsingServiceResponseParsingTest {

    private lateinit var chatModel: ChatModel
    private lateinit var service: ScheduleTimeParsingService

    @BeforeEach
    fun setup() {
        chatModel = mock()
        whenever(chatModel.options).thenReturn(OpenAiChatOptions.builder().build())
        service = ScheduleTimeParsingService(chatModel, jsr310JsonMapper(), AiProperties(), 9)
    }

    private fun givenChatAnswer(chatAnswer: String) {
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(listOf(Generation(AssistantMessage(chatAnswer))))
        )
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
    fun `parseScheduleTime extracts final JSON after an unclosed duplicated input JSON`() {
        val chatAnswer = """
            <thought>* Input: `{"date":"2026-10-23","content":"소방서 견학 10시 부터 10* Input: `{"date":"2026-10-23","content":"소방서 견학 10시 부터 10시반 까지"}`
            {"result":true,"hasTime":true,"startDateTime":"2026-10-23T10:00:00","endDateTime":"2026-10-23T10:30:00","content":"소방서 견학"}
        """.trimIndent()
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(listOf(Generation(AssistantMessage(chatAnswer))))
        )

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시 부터 10시반 까지")
        )

        assertThat(response.result).isTrue()
        assertThat(response.hasTime).isTrue()
        assertThat(response.startDateTime).isEqualTo("2026-10-23T10:00:00")
        assertThat(response.endDateTime).isEqualTo("2026-10-23T10:30:00")
        assertThat(response.content).isEqualTo("소방서 견학")
    }

    @Test
    fun `parseScheduleTime selects last response JSON and preserves escaped quotes and braces in content`() {
        val content = "소방서 {견학} \"안내\" \\ 자료"
        val finalResponse = ScheduleTimeParsingResponse(result = true, hasTime = false, content = content)
        val chatAnswer = """{"result":false,"hasTime":false}
            ${jsr310JsonMapper().writeValueAsString(finalResponse)}
            trailing malformed JSON {"content":"unfinished
        """.trimIndent()
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(listOf(Generation(AssistantMessage(chatAnswer))))
        )

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시")
        )

        assertThat(response.result).isTrue()
        assertThat(response.hasTime).isFalse()
        assertThat(response.content).isEqualTo(content)
    }

    @Test
    fun `parsing failure logs entire original response when no JSON candidate is valid`() {
        val request = ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "견학 10시")
        val chatAnswer = "<thought>\n" + "추론 내용 ".repeat(100) + "\n{\"result\":true"
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(listOf(Generation(AssistantMessage(chatAnswer))))
        )

        val response = service.parseScheduleTime(request)
        val logMessage = response.toLogMessage(request)

        assertThat(response.result).isFalse()
        assertThat(chatAnswer.length).isGreaterThan(500)
        assertThat(response.rawResponse).isEqualTo(chatAnswer)
        assertThat(jsr310JsonMapper().readTree(logMessage)["rawResponse"].asText()).isEqualTo(chatAnswer)
        assertThat(logMessage).doesNotContain("\n", "\r")
    }

    @Test
    fun `deserialization failure logs original thinking and fences instead of extracted JSON`() {
        val request = ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "견학 10시")
        val chatAnswer = "<thought>" + "추론 내용 ".repeat(100) +
            "</thought>\n```json\n{\"result\":[],\"hasTime\":true}\n```"
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(listOf(Generation(AssistantMessage(chatAnswer))))
        )

        val response = service.parseScheduleTime(request)

        assertThat(response.result).isFalse()
        assertThat(response.errorType).isNotBlank()
        assertThat(response.rawResponse).isEqualTo(chatAnswer)
        assertThat(jsr310JsonMapper().readTree(response.toLogMessage(request))["rawResponse"].asText())
            .isEqualTo(chatAnswer)
    }

    @ParameterizedTest
    @ValueSource(strings = ["thought", "think", "THOUGHT"])
    fun `parseScheduleTime finds final answer after thinking with an unclosed object and odd quotes`(tag: String) {
        val loggedThinking = listOf(
            "<$tag>*   Input: `{\"date\":\"202*   Input: `{\"date\":\"2026-10-23\",\"content\":\"소방서 견학 10시~10시반\"}`",
            "    *   Task: Extract time from Korean schedule text.",
            "    *   Output: JSON only.",
            "",
            "    *   Text: \"소방서 견학 10시~10시반\"",
            "    *   Date: \"2026-10-23\"",
            "    *   Time markers found: \"10시\", \"10시반\" (range indicated by \"~\").",
            "    *   Time values:",
            "        *   Start: 10시.",
            "        *   End: 10시반 (10:30).",
            "    *   AM/PM Determination:",
            "        *   10시 is generally AM (Rule: 7-11 = AM).",
            "        *   Activity \"소방서 견학\" (Fire station visit).",
        ).joinToString("\n")
        val chatAnswer = loggedThinking + "\n</$tag>\n```json\n" +
            """{"result":true,"hasTime":true,"startDateTime":"2026-10-23T10:00:00","endDateTime":"2026-10-23T10:30:00","content":"소방서 견학"}""" +
            "\n```"
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시~10시반")
        )

        assertThat(response.result).isTrue()
        assertThat(response.hasTime).isTrue()
        assertThat(response.startDateTime).isEqualTo("2026-10-23T10:00:00")
        assertThat(response.endDateTime).isEqualTo("2026-10-23T10:30:00")
        assertThat(response.content).isEqualTo("소방서 견학")
    }

    @Test
    fun `parseScheduleTime uses only the answer after the closing thinking tag`() {
        val chatAnswer = """
            <thought>Similar example: "카페에서 4시 커피" → {"result":true,"hasTime":true,"startDateTime":"2026-10-23T16:00:00","endDateTime":"2026-10-23T16:00:00","content":"카페에서 커피"}
            Unbalanced echo: `{"content":"소방서 견학 10
            </thought>
            {"result":true,"hasTime":true,"startDateTime":"2026-10-23T10:00:00","endDateTime":"2026-10-23T10:00:00","content":"소방서 견학"}
        """.trimIndent()
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시")
        )

        assertThat(response.result).isTrue()
        assertThat(response.startDateTime).isEqualTo("2026-10-23T10:00:00")
        assertThat(response.content).isEqualTo("소방서 견학")
    }

    @Test
    fun `parseScheduleTime fails instead of using example JSON from thinking when final answer is truncated`() {
        val chatAnswer = """
            <thought>Similar example: "카페에서 4시 커피" → {"result":true,"hasTime":true,"startDateTime":"2026-10-23T16:00:00","endDateTime":"2026-10-23T16:00:00","content":"카페에서 커피"}</thought>
            {"result":true,"hasTime":true,"startDateTime":"2026-10-23T10:00:00"
        """.trimIndent()
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시")
        )

        assertThat(response.result).isFalse()
        assertThat(response.hasTime).isFalse()
        assertThat(response.startDateTime).isNull()
        assertThat(response.content).isNull()
        assertThat(response.errorType).isNotBlank()
        assertThat(response.rawResponse).isEqualTo(chatAnswer)
    }

    @Test
    fun `parseScheduleTime picks the last answer when thinking is never closed`() {
        val chatAnswer = """
            <thought>Similar example: "카페에서 4시 커피" → {"result":true,"hasTime":true,"startDateTime":"2026-10-23T16:00:00","endDateTime":"2026-10-23T16:00:00","content":"카페에서 커피"}
            {"result":true,"hasTime":true,"startDateTime":"2026-10-23T10:00:00","endDateTime":"2026-10-23T10:00:00","content":"소방서 견학"}
        """.trimIndent()
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "소방서 견학 10시")
        )

        assertThat(response.result).isTrue()
        assertThat(response.startDateTime).isEqualTo("2026-10-23T10:00:00")
        assertThat(response.content).isEqualTo("소방서 견학")
    }

    @Test
    fun `parseScheduleTime searches only after the last closing tag even without an opening tag`() {
        val chatAnswer = "reasoning without an opening tag {\"result\":false,\"hasTime\":false}</thought>\n" +
            """{"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"주말 데이트"}"""
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "주말 데이트 2시")
        )

        assertThat(response.result).isTrue()
        assertThat(response.content).isEqualTo("주말 데이트")
    }

    @Test
    fun `parsing failure log keeps head and a longer tail where the final answer is`() {
        val request = ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "견학 10시")
        val chatAnswer = "<thought>" + "추론 내용 ".repeat(5_000) + "</thought>\n{\"result\":[],\"hasTime\":true}"
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(request)
        val rawResponse = requireNotNull(response.rawResponse)
        val headLimit = ScheduleTimeParsingService.RAW_RESPONSE_HEAD_LIMIT
        val tailLimit = ScheduleTimeParsingService.RAW_RESPONSE_TAIL_LIMIT
        val omitted = chatAnswer.length - headLimit - tailLimit

        assertThat(response.result).isFalse()
        assertThat(tailLimit).isGreaterThan(headLimit)
        assertThat(chatAnswer.length).isGreaterThan(headLimit + tailLimit)
        assertThat(rawResponse)
            .startsWith(chatAnswer.take(headLimit))
            .endsWith(chatAnswer.takeLast(tailLimit))
            .endsWith("{\"result\":[],\"hasTime\":true}")
            .contains(" ...[$omitted chars omitted]... ")
        assertThat(rawResponse.length).isLessThan(headLimit + tailLimit + 100)
        assertThat(jsr310JsonMapper().readTree(response.toLogMessage(request))["rawResponse"].asText())
            .isEqualTo(rawResponse)
    }

    @Test
    fun `parsing failure keeps raw response intact at exactly the log limit`() {
        val limit = ScheduleTimeParsingService.RAW_RESPONSE_HEAD_LIMIT + ScheduleTimeParsingService.RAW_RESPONSE_TAIL_LIMIT
        val chatAnswer = "<thought>" + "x".repeat(limit - "<thought>".length)
        givenChatAnswer(chatAnswer)

        val response = service.parseScheduleTime(
            ScheduleTimeParsingRequest(LocalDate.of(2026, 10, 23), "견학 10시")
        )

        assertThat(chatAnswer.length).isEqualTo(limit)
        assertThat(response.result).isFalse()
        assertThat(response.rawResponse).isEqualTo(chatAnswer)
    }

    @Test
    fun `chat client applies configured timeout and retries while preserving model options`() {
        val baseOptions = OpenAiChatOptions.builder()
            .model("preserved-model")
            .temperature(0.25)
            .build()
        whenever(chatModel.options).thenReturn(baseOptions)
        val capturedPrompt = AtomicReference<Prompt>()
        whenever(chatModel.call(any<Prompt>())).thenAnswer { invocation ->
            capturedPrompt.set(invocation.getArgument<Prompt>(0))
            ChatResponse(
                listOf(
                    Generation(
                        AssistantMessage(
                            """{"result":true,"hasTime":true,"startDateTime":"2025-02-28T14:00:00","endDateTime":"2025-02-28T14:00:00","content":"일정"}"""
                        )
                    )
                )
            )
        }

        val configuredService = ScheduleTimeParsingService(
            chatModel = chatModel,
            jsonMapper = jsr310JsonMapper(),
            aiProperties = AiProperties(
                chat = AiProperties.ChatProperties(
                    connectTimeout = Duration.ofSeconds(30),
                    readTimeout = Duration.ofSeconds(120),
                )
            ),
            maxRetries = 9,
        )

        configuredService.parseScheduleTime(
            ScheduleTimeParsingRequest(
                date = LocalDate.of(2025, 2, 28),
                content = "2시 일정"
            )
        )

        val capturedOptions = (capturedPrompt.get()?.options as? OpenAiChatOptions)
            ?: error("ChatClient did not pass OpenAiChatOptions to the model")
        assertThat(capturedOptions.timeout).isEqualTo(Duration.ofSeconds(120))
        assertThat(capturedOptions.maxRetries).isEqualTo(9)
        assertThat(capturedOptions.model).isEqualTo("preserved-model")
        assertThat(capturedOptions.temperature).isEqualTo(0.25)
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
    fun `log context preserves before and after content on one escaped line`() {
        val request = ScheduleTimeParsingRequest(
            date = LocalDate.of(2025, 2, 28),
            content = "이재상담5시20분\n다음 줄",
        )
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(
                listOf(
                    Generation(
                        AssistantMessage(
                            """{"result":true,"hasTime":true,"startDateTime":"2025-02-28T17:20:00","endDateTime":"2025-02-28T17:20:00","content":"이재상담\n후속"}"""
                        )
                    )
                )
            )
        )

        val response = service.parseScheduleTime(request)
        val logMessage = response.toLogMessage(
            request,
            mapOf("scheduleId" to "schedule-123", "memberId" to 7L, "memberName" to "민수"),
        )

        assertThat(logMessage)
            .contains("\"contentBefore\":\"이재상담5시20분\\n다음 줄\"")
            .contains("\"contentAfter\":\"이재상담\\n후속\"")
            .contains("\"time\":\"2025-02-28T17:20:00\"")
            .contains("\"scheduleId\":\"schedule-123\"")
            .contains("\"memberId\":7")
            .contains("\"memberName\":\"민수\"")
            .contains("\"hasTime\":true")
            .contains("\"result\":true")
            .doesNotContain("\n")
    }

    @Test
    fun `invalid model JSON includes error type and escaped raw response in log context`() {
        val request = ScheduleTimeParsingRequest(
            date = LocalDate.of(2025, 2, 28),
            content = "진료 3시",
        )
        val invalidJson = """{"result":[],"hasTime":true,"content":"첫 줄\\n둘째 줄"}"""
        whenever(chatModel.call(any<Prompt>())).thenReturn(
            ChatResponse(
                listOf(
                    Generation(
                        AssistantMessage(invalidJson)
                    )
                )
            )
        )

        val response = service.parseScheduleTime(request)
        val logMessage = response.toLogMessage(request)
        val errorMessage = requireNotNull(response.errorMessage)
        val logJson = jsr310JsonMapper().readTree(logMessage)

        assertThat(response.result).isFalse()
        assertThat(response.errorType).isNotBlank()
        assertThat(errorMessage).isNotBlank()
        assertThat(logJson["rawResponse"].asText()).isEqualTo(invalidJson)
        assertThat(logJson["errorType"].asText()).isNotBlank()
        assertThat(logJson.has("errorMessage")).isFalse()
        assertThat(logMessage).doesNotContain("\n", "\r")
    }

    @Test
    fun `internal error type is not serialized in response`() {
        val response = ScheduleTimeParsingResponse(errorType = "IllegalArgumentException")

        val serialized = jsr310JsonMapper().writeValueAsString(response)

        assertThat(serialized)
            .doesNotContain("errorType")
            .doesNotContain("IllegalArgumentException")
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
