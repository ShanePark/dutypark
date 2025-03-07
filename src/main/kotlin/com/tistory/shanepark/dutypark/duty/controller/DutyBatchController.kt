package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplateDto
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.context.ApplicationContext
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

@RestController
@RequestMapping("/api/duty_batch")
class DutyBatchController(
    private val dutyService: DutyService,
    private val memberService: MemberService,
    private val applicationContext: ApplicationContext,
) {
    private val log = logger()

    @GetMapping("/templates")
    fun getTemplates(
        @Login(required = false) loginMember: LoginMember?,
    ): List<DutyBatchTemplateDto> {
        return DutyBatchTemplate.entries.map { DutyBatchTemplateDto(it) }
    }

    @PostMapping
    fun batchUpload(
        @Login loginMember: LoginMember,
        @RequestParam memberId: Long,
        @RequestParam file: MultipartFile,
        @RequestParam year: Int,
        @RequestParam month: Int,
    ): DutyBatchResult {
        if (dutyService.canEdit(loginMember = loginMember, memberId = memberId).not())
            throw DutyparkAuthException("login member doesn't have permission to edit duty")

        val dutyBatchTemplate =
            memberService.getDutyBatchTemplate(memberId) ?: throw IllegalArgumentException("No duty-batch template")

        val dutyBatchService = applicationContext.getBean(dutyBatchTemplate.batchServiceClass) as DutyBatchService
        return try {
            log.info("batch duty upload by $loginMember for member $memberId. year=$year, month=$month")
            dutyBatchService.batchUploadMember(memberId = memberId, file = file, yearMonth = YearMonth.of(year, month))
        } catch (e: DutyBatchException) {
            DutyBatchResult.fail(e.batchErrorMessage)
        }
    }

}
