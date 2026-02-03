package com.tistory.shanepark.dutypark.policy.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.hamcrest.Matchers.nullValue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

@AutoConfigureMockMvc
class PolicyControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var policyVersionRepository: PolicyVersionRepository

    @Test
    fun `get current policies returns nulls when no policies exist`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/policies/current")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.terms").value(nullValue()))
            .andExpect(jsonPath("$.privacy").value(nullValue()))
    }

    @Test
    fun `get current policies returns latest versions`() {
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.TERMS,
                version = "1.0",
                content = "terms-v1",
                effectiveDate = LocalDate.of(2024, 1, 1)
            )
        )
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.TERMS,
                version = "2.0",
                content = "terms-v2",
                effectiveDate = LocalDate.of(2025, 1, 1)
            )
        )
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.PRIVACY,
                version = "1.0",
                content = "privacy-v1",
                effectiveDate = LocalDate.of(2024, 6, 1)
            )
        )
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.PRIVACY,
                version = "1.1",
                content = "privacy-v1.1",
                effectiveDate = LocalDate.of(2024, 12, 1)
            )
        )

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/policies/current")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.terms.version").value("2.0"))
            .andExpect(jsonPath("$.privacy.version").value("1.1"))
    }

    @Test
    fun `get current policy returns bad request for invalid type`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/policies/invalid")
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `get current policy returns not found when missing`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/policies/terms")
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `get current policy returns policy by type`() {
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.TERMS,
                version = "3.0",
                content = "terms-v3",
                effectiveDate = LocalDate.of(2026, 1, 1)
            )
        )

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/policies/terms")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.version").value("3.0"))
            .andExpect(jsonPath("$.policyType").value("TERMS"))
    }
}
