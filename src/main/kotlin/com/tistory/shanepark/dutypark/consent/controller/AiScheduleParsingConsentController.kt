package com.tistory.shanepark.dutypark.consent.controller

import com.tistory.shanepark.dutypark.consent.dto.AiScheduleParsingConsentResponse
import com.tistory.shanepark.dutypark.consent.dto.UpdateAiScheduleParsingConsentRequest
import com.tistory.shanepark.dutypark.consent.service.AiScheduleParsingConsentService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/consents/ai-schedule-parsing")
class AiScheduleParsingConsentController(
    private val consentService: AiScheduleParsingConsentService,
) {
    @GetMapping
    fun getConsent(@Login loginMember: LoginMember): AiScheduleParsingConsentResponse =
        consentService.getConsent(loginMember.id)

    @PutMapping
    fun updateConsent(
        @Login loginMember: LoginMember,
        @RequestBody request: UpdateAiScheduleParsingConsentRequest,
        servletRequest: HttpServletRequest,
    ): AiScheduleParsingConsentResponse = consentService.updateConsent(
        memberId = loginMember.id,
        consented = request.consented,
        policyVersion = request.policyVersion,
        ipAddress = servletRequest.remoteAddr,
        userAgent = servletRequest.getHeader("User-Agent"),
    )
}
