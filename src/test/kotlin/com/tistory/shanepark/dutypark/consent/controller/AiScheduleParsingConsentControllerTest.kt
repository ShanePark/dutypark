package com.tistory.shanepark.dutypark.consent.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEventType
import com.tistory.shanepark.dutypark.consent.repository.AiScheduleParsingConsentEventRepository
import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.put
import java.time.LocalDate

class AiScheduleParsingConsentControllerTest : RestDocsTest() {
    @Autowired
    lateinit var policyVersionRepository: PolicyVersionRepository

    @Autowired
    lateinit var consentEventRepository: AiScheduleParsingConsentEventRepository

    @Test
    fun `GET requires authentication`() {
        mockMvc.get("/api/consents/ai-schedule-parsing")
            .andExpect {
                status { isUnauthorized() }
                jsonPath("$.code") { value("auth.required") }
            }
    }

    @Test
    fun `GET returns current policy and unconsented state`() {
        saveCurrentPolicy()

        mockMvc.get("/api/consents/ai-schedule-parsing") {
            header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        }.andExpect {
            status { isOk() }
            jsonPath("$.policy.policyType") { value("AI_SCHEDULE_PARSING") }
            jsonPath("$.currentPolicyVersion") { value("2026-08-13") }
            jsonPath("$.consented") { value(false) }
            jsonPath("$.consentVersion") { doesNotExist() }
            jsonPath("$.needsRenewal") { value(false) }
            jsonPath("$.consentedAt") { doesNotExist() }
            jsonPath("$.revokedAt") { doesNotExist() }
        }
    }

    @Test
    fun `PUT grant requires exact current version and is idempotent`() {
        saveCurrentPolicy()

        mockMvc.put("/api/consents/ai-schedule-parsing") {
            header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"consented":true,"policyVersion":"old"}"""
        }.andExpect {
            status { isBadRequest() }
            jsonPath("$.code") { value("consent.aiScheduleParsing.policyVersionMismatch") }
        }

        repeat(2) {
            mockMvc.put("/api/consents/ai-schedule-parsing") {
                header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
                contentType = MediaType.APPLICATION_JSON
                header("User-Agent", "consent-test-agent")
                content = """{"consented":true,"policyVersion":"2026-08-13"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.consented") { value(true) }
                jsonPath("$.consentVersion") { value("2026-08-13") }
                jsonPath("$.needsRenewal") { value(false) }
                jsonPath("$.consentedAt") { exists() }
            }
        }

        val events = consentEventRepository.findAll()
        assertThat(events).hasSize(1)
        assertThat(events.single().eventType).isEqualTo(AiScheduleParsingConsentEventType.GRANTED)
        assertThat(events.single().userAgent).isEqualTo("consent-test-agent")
    }

    @Test
    fun `PUT revoke records once and does not require a version`() {
        saveCurrentPolicy()
        putConsent(true, "2026-08-13")

        repeat(2) {
            mockMvc.put("/api/consents/ai-schedule-parsing") {
                header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"consented":false}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.consented") { value(false) }
                jsonPath("$.consentVersion") { doesNotExist() }
                jsonPath("$.needsRenewal") { value(false) }
                jsonPath("$.revokedAt") { exists() }
            }
        }

        val events = consentEventRepository.findAll()
        assertThat(events).hasSize(2)
        assertThat(events.last().eventType).isEqualTo(AiScheduleParsingConsentEventType.REVOKED)
        assertThat(events.last().policyVersion).isNull()
    }

    @Test
    fun `GET policy unavailable returns machine readable not found code`() {
        mockMvc.get("/api/consents/ai-schedule-parsing") {
            header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        }.andExpect {
            status { isNotFound() }
            jsonPath("$.code") { value("consent.aiScheduleParsing.policyUnavailable") }
        }
    }

    private fun putConsent(consented: Boolean, policyVersion: String?) {
        val versionField = policyVersion?.let { ",\"policyVersion\":\"$it\"" }.orEmpty()
        mockMvc.put("/api/consents/ai-schedule-parsing") {
            header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
            contentType = MediaType.APPLICATION_JSON
            content = """{"consented":$consented$versionField}"""
        }.andExpect { status { isOk() } }
    }

    private fun saveCurrentPolicy() {
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.AI_SCHEDULE_PARSING,
                version = "2026-08-13",
                content = "AI schedule parsing policy",
                effectiveDate = LocalDate.of(2026, 8, 13),
            )
        )
    }
}
