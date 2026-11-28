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

        private val analyzerDelegate = lazy {
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
        private val analyzer: UserAgentAnalyzer by analyzerDelegate

        /** Building the analyzer takes about a second, so do it before the first request needs it. */
        fun warmUp() {
            analyzer
        }

        internal fun isAnalyzerInitialized(): Boolean = analyzerDelegate.isInitialized()

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

        fun fromStoredValue(value: String?): UserAgentInfo? {
            if (value == null) return null
            // Stored values are raw user agents today; skip the throwing JSON attempt for them.
            if (!value.trimStart().startsWith('{')) return parse(value)
            return fromJson(value) ?: parse(value)
        }
    }
}
