package com.tistory.shanepark.dutypark.security.domain.dto

import nl.basjes.parse.useragent.UserAgentAnalyzer
import tools.jackson.module.kotlin.jacksonMapperBuilder
import tools.jackson.module.kotlin.readValue

data class UserAgentInfo(
    val os: String,
    val browser: String,
    val device: String,
) {
    fun toJson(): String = jsonMapper.writeValueAsString(this)

    companion object {
        private val jsonMapper = jacksonMapperBuilder().build()

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
                jsonMapper.readValue<UserAgentInfo>(json)
            } catch (e: Exception) {
                null
            }
        }
    }
}
