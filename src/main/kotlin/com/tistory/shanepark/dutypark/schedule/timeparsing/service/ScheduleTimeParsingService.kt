package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.fasterxml.jackson.core.JsonProcessingException
import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import org.springframework.ai.chat.client.ChatClient
import org.springframework.ai.chat.model.ChatModel
import org.springframework.stereotype.Service

@Service
class ScheduleTimeParsingService(
    chatModel: ChatModel,
    private val objectMapper: ObjectMapper,
) {
    private val chatClient = ChatClient.builder(chatModel).build()
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(ScheduleTimeParsingService::class.java)

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
            objectMapper.readValue(json, ScheduleTimeParsingResponse::class.java)
        } catch (e: JsonProcessingException) {
            log.warn("Failed to parse JSON:\n$json", e)
            ScheduleTimeParsingResponse(result = false)
        }
    }

    private fun generatePrompt(request: ScheduleTimeParsingRequest): String {
        val jsonRequest = objectMapper.writeValueAsString(request)
        return """
              Task: Extract time from the text and return a JSON response.
 
                 - Identify time and convert it to ISO 8601 (YYYY-MM-DDTHH:MM:SS).
                 - If a time range is mentioned (e.g., "2시~4시"), assign the first time to `startDateTime` and the second time to `endDateTime`.
                 - If only one time is mentioned, set both `startDateTime` and `endDateTime` to the same value.
                 - Remove the identified time from the text. The remaining text becomes `content`.
                 - if AM/PM is not specified, assume based on the content.
                 - If no time is found, return:
                   { "result": true, "hasTime": false }
                 - If more than two time exist, return:
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
