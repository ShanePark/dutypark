package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplateDto
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
    fun getTemplates(): List<DutyBatchTemplateDto> {
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
            throw AuthException("duty.edit.forbidden")

        val member = memberService.findPreviewById(memberId)
        val dutyBatchTemplate = memberService.getDutyBatchTemplate(memberId)
            ?: throw IllegalArgumentException("dutyBatch.template.required")

        val dutyBatchService = applicationContext.getBean(dutyBatchTemplate.batchServiceClass)
        val yearMonth = YearMonth.of(year, month)
        val target = mapOf(
            "type" to "Member",
            "memberId" to member.id,
            "memberName" to member.name,
            "teamId" to member.teamId,
            "teamName" to member.team,
        )
        val uploadDetails = mapOf(
            "template" to dutyBatchTemplate.name,
            "year" to year,
            "month" to month,
            "fileName" to file.safeDutyBatchAuditFilename(),
            "fileSizeBytes" to file.size,
        )
        return try {
            val result = dutyBatchService.batchUploadMember(memberId = memberId, file = file, yearMonth = yearMonth)
            if (result.result) {
                log.auditEventAfterCommit(
                    event = "duty_batch.member_uploaded",
                    actor = loginMember.toAuditActor(),
                    target = target,
                    details = uploadDetails + mapOf(
                        "startDate" to result.startDate,
                        "endDate" to result.endDate,
                        "workingDays" to result.workingDays,
                        "offDays" to result.offDays,
                    ),
                )
            } else {
                log.warn(
                    "Member duty batch upload failed {}",
                    auditContext(
                        mapOf(
                            "event" to "duty_batch.member_upload_failed",
                            "actor" to loginMember.toAuditActor(),
                            "target" to target,
                            "details" to uploadDetails + mapOf(
                                "errorCode" to result.errorCode,
                                "errorDetails" to result.errorDetails,
                            ),
                        )
                    ),
                )
            }
            result
        } catch (e: DutyBatchException) {
            log.warn(
                "Member duty batch upload failed {}",
                auditContext(
                    mapOf(
                        "event" to "duty_batch.member_upload_failed",
                        "actor" to loginMember.toAuditActor(),
                        "target" to target,
                        "details" to uploadDetails + mapOf(
                            "errorCode" to e.errorCode,
                            "errorDetails" to e.errorDetails,
                        ),
                    )
                ),
            )
            DutyBatchResult.fail(e.errorCode, e.errorDetails)
        }
    }

}

private fun MultipartFile.safeDutyBatchAuditFilename(): String? = originalFilename
    ?.substringAfterLast('/')
    ?.substringAfterLast('\\')
    ?.takeLast(120)
