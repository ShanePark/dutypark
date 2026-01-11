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

    fun parseScheduleTime(request: ScheduleTimeParsingRequest): ScheduleTimeParsingResponse {
        val prompt = generatePrompt(request)
        val chatResponse = chatClient.prompt(prompt)
            .call()
            .chatResponse()
        if (chatResponse == null) {
            return ScheduleTimeParsingResponse(result = false)
        }
        val chatAnswer = chatResponse.result.output.text
        val response = parseChatAnswer(chatAnswer)
        log.info("ScheduleTimeParsing==\n $request \nResponse:\n $response\n")
        return response
    }

    private fun parseChatAnswer(chatAnswer: String): ScheduleTimeParsingResponse {
        val json = chatAnswer.lines()
            .filter { !it.contains("```") }
            .joinToString("\n")
        return try {
            jsonMapper.readValue(json, ScheduleTimeParsingResponse::class.java)
        } catch (e: Exception) {
            log.warn("Failed to parse JSON:\n$json", e)
            ScheduleTimeParsingResponse(result = false)
        }
    }

    private fun generatePrompt(request: ScheduleTimeParsingRequest): String {
        val jsonRequest = jsonMapper.writeValueAsString(request)
        return """
              Task: Extract time from the text and return a JSON response.
 
                 - Identify time and convert it to ISO 8601 (YYYY-MM-DDTHH:MM:SS).
                 - If a time range is mentioned (e.g., "2시~4시"), assign the first time to `startDateTime` and the second time to `endDateTime`.
                 - If only one time is mentioned, set both `startDateTime` and `endDateTime` to the same value.
                 - Remove the identified time from the text. The remaining text becomes `content`.
                 - If AM/PM is not specified, infer based on context (e.g., common schedules for activities like "진료", "회의", "수업" usually occur during the day).                 
                 - If no time is found, return:
                   { "result": true, "hasTime": false, "content": "<original text>" }
                 - If "오전" or "오후" appears without an accompanying number, do not treat it as a valid time. Return `{ "result": true, "hasTime": false, "content": "<original text>" }`.
                 - If there are two or more separate, distinct times (not a range), return:
                   { "result": false }
    
                 Respond in JSON format only, with the following fields:
                 - result
                 - hasTime
                 - startDateTime
                 - endDateTime
                 - content
     
                 No explanations.
 
                 ===
                 input:
                 
                 $jsonRequest
        """.trimIndent()
    }

}
