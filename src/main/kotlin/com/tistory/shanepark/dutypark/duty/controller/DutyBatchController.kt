package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.duty.batch.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.DutyBatchTemplateDto
import com.tistory.shanepark.dutypark.duty.service.DutyBatchService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/duty_batch/")
class DutyBatchController(
    private val dutyBatchService: DutyBatchService,
) {
    val log: Logger = org.slf4j.LoggerFactory.getLogger(DutyBatchController::class.java)

    @GetMapping("/templates")
    fun getTemplates(
        @Login(required = false) loginMember: LoginMember?,
    ): List<DutyBatchTemplateDto> {
        return DutyBatchTemplate.entries.map { DutyBatchTemplateDto(it) }
    }

}
