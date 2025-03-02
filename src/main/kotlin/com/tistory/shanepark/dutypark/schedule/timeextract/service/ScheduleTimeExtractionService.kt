package com.tistory.shanepark.dutypark.schedule.timeextract.service

import com.fasterxml.jackson.core.JsonProcessingException
import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.schedule.timeextract.domain.ScheduleTimeExtractionRequest
import com.tistory.shanepark.dutypark.schedule.timeextract.domain.ScheduleTimeExtractionResponse
import org.springframework.ai.chat.client.ChatClient
import org.springframework.ai.chat.model.ChatModel

class ScheduleTimeExtractionService(
    chatModel: ChatModel,
    private val objectMapper: ObjectMapper
) {
    private val chatClient = ChatClient.builder(chatModel).build()
    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(ScheduleTimeExtractionService::class.java)

    fun extractScheduleTime(request: ScheduleTimeExtractionRequest): ScheduleTimeExtractionResponse {
        val prompt = generatePrompt(request)
        val chatResponse = chatClient.prompt(prompt)
            .call()
            .chatResponse()
        if (chatResponse == null) {
            return ScheduleTimeExtractionResponse(result = false)
        }
        val chatAnswer = chatResponse.result.output.text
        val response = parseChatAnswer(chatAnswer)
        log.info("ScheduleTimeExtraction Request:\n $request \nResponse:\n $response")
        return response
    }

    private fun parseChatAnswer(chatAnswer: String): ScheduleTimeExtractionResponse {
        val json = chatAnswer.lines()
            .filter { !it.contains("```") }
            .joinToString("\n")
        return try {
            objectMapper.readValue(json, ScheduleTimeExtractionResponse::class.java)
        } catch (e: JsonProcessingException) {
            log.warn("Failed to parse JSON: $json", e)
            ScheduleTimeExtractionResponse(result = false)
        }
    }

    private fun generatePrompt(request: ScheduleTimeExtractionRequest): String {
        val jsonRequest = objectMapper.writeValueAsString(request)
        return """
              Task: Extract time from the text and return a JSON response.
 
                 - Identify time and convert it to ISO 8601 (YYYY-MM-DDTHH:MM:SS).
                 - Remove the identified time from the text. The remaining text becomes `content`.
                 - If no time is found, return:
                   { "result": true, "hasTime": false}
                 - If multiple time exists, return:
                   { "result": false }
 
                 Respond in JSON format only, with the following fields:
                 - result
                 - hasTime
                 - dateTime
                 - content
 
                 No explanations.
 
                 ===
                 input:
                 
                 $jsonRequest
        """.trimIndent()
    }

}
