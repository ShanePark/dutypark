package com.tistory.shanepark.dutypark.security.domain.dto

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import nl.basjes.parse.useragent.UserAgentAnalyzer

data class UserAgentInfo(
    val os: String,
    val browser: String,
    val device: String,
) {
    fun toJson(): String = objectMapper.writeValueAsString(this)

    companion object {
        private val objectMapper = jacksonObjectMapper()

        private val analyzer: UserAgentAnalyzer by lazy {
            UserAgentAnalyzer
                .newBuilder()
                .withFields(
                    "DeviceClass",
                    "DeviceName",
                    "OperatingSystemName",
                    "AgentName"
                )
                .withCache(1000)
                .build()
        }

        fun parse(userAgent: String?): UserAgentInfo? {
            if (userAgent == null) return null
            val parsed = analyzer.parse(userAgent)
            return UserAgentInfo(
                os = parsed.getValue("OperatingSystemName") ?: "Unknown",
                browser = parsed.getValue("AgentName") ?: "Unknown",
                device = parsed.getValue("DeviceName") ?: "Unknown",
            )
        }

        fun fromJson(json: String?): UserAgentInfo? {
            if (json == null) return null
            return try {
                objectMapper.readValue<UserAgentInfo>(json)
            } catch (e: Exception) {
                null
            }
        }
    }
}
