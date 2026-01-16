package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import org.springframework.ai.chat.client.ChatClient
import org.springframework.ai.chat.model.ChatModel
import org.springframework.stereotype.Service
import tools.jackson.databind.json.JsonMapper

@Service
class ScheduleTimeParsingService(
    chatModel: ChatModel,
    private val jsonMapper: JsonMapper,
) {
    private val chatClient = ChatClient.builder(chatModel).build()
    private val log = logger()

    companion object {
        private val TIME_INDICATOR_PATTERN = Regex(
            """[0-9]|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|정오|자정"""
        )
    }

    fun parseScheduleTime(request: ScheduleTimeParsingRequest): ScheduleTimeParsingResponse {
        if (!hasAnyTimeIndicator(request.content)) {
            return ScheduleTimeParsingResponse(
                result = true,
                hasTime = false,
                content = request.content
            )
        }

        val prompt = generatePrompt(request)
        val chatResponse = chatClient.prompt(prompt)
            .call()
            .chatResponse()
        if (chatResponse == null) {
            return ScheduleTimeParsingResponse(result = false)
        }
        val chatAnswer = chatResponse.result.output.text
        val response = parseChatAnswer(chatAnswer)
        log.info("Time parsing result: request={}, hasTime={}, result={}", request, response.hasTime, response.result)
        return response
    }

    private fun hasAnyTimeIndicator(content: String): Boolean {
        return TIME_INDICATOR_PATTERN.containsMatchIn(content)
    }

    private fun parseChatAnswer(chatAnswer: String): ScheduleTimeParsingResponse {
        val json = chatAnswer.lines()
            .filter { !it.contains("```") }
            .joinToString("\n")
        return try {
            jsonMapper.readValue(json, ScheduleTimeParsingResponse::class.java)
        } catch (e: Exception) {
            log.warn("Failed to parse JSON: {}", json, e)
            ScheduleTimeParsingResponse(result = false)
        }
    }

    private fun generatePrompt(request: ScheduleTimeParsingRequest): String {
        val jsonRequest = jsonMapper.writeValueAsString(request)
        return """
            Task: Extract time from Korean schedule text. Return JSON only.

            EXAMPLES (date=2025-01-15):

            "카페에서 4시 커피" → {"result":true,"hasTime":true,"startDateTime":"2025-01-15T16:00:00","endDateTime":"2025-01-15T16:00:00","content":"카페에서 커피"}
            (4시 without indicator = PM)

            "오전 9시 출근" → {"result":true,"hasTime":true,"startDateTime":"2025-01-15T09:00:00","endDateTime":"2025-01-15T09:00:00","content":"출근"}
            (오전 + 9시 = 09:00)

            "조깅 5시반 시작" → {"result":true,"hasTime":true,"startDateTime":"2025-01-15T05:30:00","endDateTime":"2025-01-15T05:30:00","content":"조깅 시작"}
            (morning exercise like 조깅/등산/산책 at 5-6시 = AM)

            "주말 데이트" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"주말 데이트"}
            (no time marker = no time, keep content as-is)

            "저녁 약속 있어" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"저녁 약속 있어"}
            (저녁 alone without number = NO time, keep content as-is)

            "이따가 회의" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"이따가 회의"}
            (relative time words like 이따가/조금뒤/나중에 = NO time, keep content as-is)

            "5명이서 저녁식사" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"5명이서 저녁식사"}
            (5명 is quantity, not time)

            "수영 1시~3시반" → {"result":true,"hasTime":true,"startDateTime":"2025-01-15T13:00:00","endDateTime":"2025-01-15T15:30:00","content":"수영"}
            (range, 1-6 = PM)

            "병원 2시쯤" → {"result":true,"hasTime":true,"startDateTime":"2025-01-15T14:00:00","endDateTime":"2025-01-15T14:00:00","content":"병원"}
            (approximate words like 쯤/대략/정도 don't affect time parsing, still hasTime=true)

            "2시 또는 5시에 만나자" → {"result":false,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":null}
            (multiple separate times = error)

            "오전 14시 회의" → {"result":false,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":null}
            (오전 + 14 is logical conflict = error, because 14 is valid hour but conflicts with 오전)

            "미팅 30시에" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"미팅 30시에"}
            (30시 is impossible hour = treat as no time, NOT error)

            "저녁 99시 모임" → {"result":true,"hasTime":false,"startDateTime":null,"endDateTime":null,"content":"저녁 99시 모임"}
            (99시 is impossible hour = no time, even with period word. Different from 오전+14 which is logical conflict)

            RULES:
            - Time needs markers: 시, 분, :, 반 (or special words 정오/자정)
            - Period word (오전/오후/저녁/밤/새벽) WITHOUT number = hasTime:false
            - Default hours: 1-6 = PM, 7-11 = AM (but consider activity context)
            - Morning activities (등산/조깅/산책/운동 출발) at 5-6시 = AM
            - result=true for normal cases (including no time found)
            - result=false only for LOGICAL errors: AM/PM conflict with valid hour (오전+14시), invalid range (18시~10시), multiple separate times
            - Impossible hours (25, 30, 99 etc) = just no time (result=true, hasTime=false), NOT error
            - CONTENT: hasTime=true → strip only time expression from content. hasTime=false → return EXACT original text

            ===
            $jsonRequest
        """.trimIndent()
    }

}
