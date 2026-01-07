package com.tistory.shanepark.dutypark.policy.controller

import com.tistory.shanepark.dutypark.policy.domain.dto.PolicyDto
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.service.PolicyService
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/policies")
class PolicyController(
    private val policyService: PolicyService
) {

    @GetMapping("/current")
    fun getCurrentPolicies(): ResponseEntity<Map<String, PolicyDto?>> {
        val terms = policyService.getCurrentPolicy(PolicyType.TERMS)?.let { PolicyDto.from(it) }
        val privacy = policyService.getCurrentPolicy(PolicyType.PRIVACY)?.let { PolicyDto.from(it) }
        return ResponseEntity.ok(mapOf("terms" to terms, "privacy" to privacy))
    }

    @GetMapping("/{type}")
    fun getCurrentPolicy(@PathVariable type: String): ResponseEntity<PolicyDto> {
        val policyType = try {
            PolicyType.valueOf(type.uppercase())
        } catch (e: IllegalArgumentException) {
            return ResponseEntity.badRequest().build()
        }

        val policy = policyService.getCurrentPolicy(policyType)
            ?: return ResponseEntity.notFound().build()

        return ResponseEntity.ok(PolicyDto.from(policy))
    }
}
