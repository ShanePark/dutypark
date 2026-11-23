package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.MyReportDto
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.dto.ScheduleReportEvidenceDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleMemberSnapshot
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.service.ScheduleRevisionService
import tools.jackson.databind.json.JsonMapper
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import java.time.LocalDateTime
import java.util.*
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.annotation.Isolation

@Service
@Transactional
class ReportService(
    private val contentReportRepository: ContentReportRepository,
    private val memberRepository: MemberRepository,
    private val scheduleRepository: ScheduleRepository,
    private val todoRepository: TodoRepository,
    private val attachmentRepository: AttachmentRepository,
    private val blockService: BlockService,
    private val slackNotifier: ReportSlackNotifier,
    private val scheduleRevisionService: ScheduleRevisionService,
    private val jsonMapper: JsonMapper,
) {

    private val log = logger()

    /**
     * Reporting does not check whether the reporter can still see the target:
     * a member must stay able to report content of somebody they already blocked.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    fun createReport(
        loginMemberId: Long,
        request: CreateReportRequest,
        loginMember: LoginMember? = null,
    ): ReportCreateResult {
        if (request.reason == ReportReason.OTHER && request.detail.isNullOrBlank()) {
            throw BadRequestException("report.detail.required")
        }

        val initialTarget = if (request.targetType == ReportTargetType.SCHEDULE) null else resolveTarget(request)
        val ownerId = initialTarget?.owner?.id
            ?: scheduleRepository.findOwnerIdById(toUuid(request.targetId)) ?: notFound()
        val lockedMembers = listOf(loginMemberId, ownerId)
            .distinct()
            .sorted()
            .associateWith { memberRepository.findMemberWithTeamForUpdate(it).orElseThrow() }
        val reporter = lockedMembers.getValue(loginMemberId)
        val owner = lockedMembers.getValue(ownerId)
        // Account deletion and blocking lock members before their schedules too.
        val target = initialTarget ?: resolveTarget(request)
        if (ownerId == loginMemberId && !target.hasDelegatedChanges) {
            throw BadRequestException("report.self")
        }
        val alsoBlock = request.alsoBlock && !target.hasDelegatedChanges && ownerId != loginMemberId

        val result = existingOpenReport(loginMemberId, request, target.scheduleVersion)
            ?.let { ReportCreateResult(id = it.id, isNew = false) }
            ?: ReportCreateResult(id = saveReport(reporter, owner, target, request).id, isNew = true)

        if (alsoBlock) {
            blockService.block(
                reporter.id!!,
                owner.id!!,
                actor = loginMember?.toAuditActor() ?: reporter.toAuditActor(),
            )
        }
        slackNotifier.reportCreated(result = result, reporter = reporter, reported = owner,
            request = request.copy(alsoBlock = alsoBlock))

        if (result.isNew) {
            log.auditEventAfterCommit(
                "report.created", loginMember?.toAuditActor() ?: reporter.toAuditActor(),
                target = mapOf(
                    "reportId" to result.id,
                    "targetType" to request.targetType,
                    "targetId" to request.targetId,
                    "reportedMemberId" to ownerId.takeIf { !target.hasDelegatedChanges },
                ),
                details = mapOf("reason" to request.reason, "status" to ReportStatus.OPEN, "alsoBlock" to alsoBlock),
            )
        }
        return result
    }

    /**
     * 신고자 본인의 접수 내역. 관리자 판단 근거는 빼고 처리 상태까지만 알려 준다.
     */
    @Transactional(readOnly = true)
    fun findMyReports(reporterId: Long, pageable: Pageable): Page<MyReportDto> {
        return contentReportRepository.findAllByReporterIdOrderByCreatedDateDesc(reporterId, pageable)
            .map(MyReportDto::of)
    }

    /**
     * 신고자 본인의 철회. 레코드는 증거로 남기고 관리자 대기열에서만 뺀다.
     * resolvedBy 는 신고를 처리한 관리자를 가리키는 자리라 본인 철회에는 비워 둔다.
     */
    fun cancelReport(
        loginMemberId: Long,
        reportId: UUID,
        loginMember: LoginMember? = null,
    ): MyReportDto {
        val report = contentReportRepository.findById(reportId).orElse(null)
            ?.takeIf { it.reporter?.id == loginMemberId }
            ?: notFound()
        if (report.status != ReportStatus.OPEN) {
            throw BadRequestException("report.cancel.notOpen")
        }

        report.status = ReportStatus.CANCELED
        report.resolvedAt = LocalDateTime.now()
        slackNotifier.reportCanceled(report)
        log.auditChangeAfterCommit(
            "report.canceled", loginMember?.toAuditActor() ?: AuditActor(loginMemberId, report.reporterName),
            target = mapOf("reportId" to report.id, "targetType" to report.targetType, "targetId" to report.targetId),
            before = mapOf("status" to ReportStatus.OPEN),
            after = mapOf("status" to report.status),
        )

        return MyReportDto.of(report)
    }

    private fun existingOpenReport(reporterId: Long, request: CreateReportRequest, scheduleVersion: Long?): ContentReport? {
        if (scheduleVersion != null) {
            return contentReportRepository.findFirstByReporterIdAndTargetTypeAndTargetIdAndScheduleVersionAndStatus(
                reporterId, request.targetType, request.targetId, scheduleVersion, ReportStatus.OPEN,
            )
        }
        return contentReportRepository.findFirstByReporterIdAndTargetTypeAndTargetIdAndStatus(
            reporterId = reporterId,
            targetType = request.targetType,
            targetId = request.targetId,
            status = ReportStatus.OPEN,
        )
    }

    private fun saveReport(
        reporter: Member,
        owner: Member,
        target: ResolvedTarget,
        request: CreateReportRequest,
    ): ContentReport {
        return contentReportRepository.save(
            ContentReport(
                reporter = reporter,
                reportedMember = owner.takeIf { !target.hasDelegatedChanges },
                targetType = request.targetType,
                targetId = request.targetId,
                reason = request.reason,
                detail = request.detail,
                contentSnapshot = target.snapshot(),
                reporterName = reporter.name,
                reportedMemberName = if (target.hasDelegatedChanges) "" else owner.name,
                scheduleVersion = target.scheduleVersion,
                scheduleEvidence = target.evidence,
            )
        )
    }

    private fun resolveTarget(request: CreateReportRequest): ResolvedTarget {
        val targetId = request.targetId
        return when (request.targetType) {
            ReportTargetType.MEMBER -> {
                val member = memberRepository.findById(targetId.toLongOrNull() ?: notFound()).orElseThrow()
                ResolvedTarget(member) { memberSnapshot(member) }
            }

            ReportTargetType.SCHEDULE -> {
                val schedule = scheduleRepository.findByIdForUpdate(toUuid(targetId)).orElseThrow()
                val evidence = scheduleRevisionService.evidenceFor(schedule, request.scheduleVersion ?: schedule.version)
                val snapshot = evidence.snapshot
                ResolvedTarget(
                    owner = schedule.member,
                    scheduleVersion = evidence.version,
                    evidence = jsonMapper.writeValueAsString(ScheduleReportEvidenceDto.of(
                        evidence,
                        ScheduleMemberSnapshot(schedule.member.id!!, schedule.member.name),
                        schedule.createdById?.let { ScheduleMemberSnapshot(it, schedule.createdByName.orEmpty()) },
                    )),
                    hasDelegatedChanges = evidence.history.any {
                        it.actorId != null && it.actorId != schedule.member.id && it.source == "HUMAN"
                    },
                ) {
                    val attachments = snapshot.attachments.joinToString { it.originalFilename }.ifEmpty { "없음" }
                    "제목: ${snapshot.displayContent}\n내용: ${snapshot.description}\n첨부: $attachments"
                }
            }

            ReportTargetType.TODO -> {
                val todo = todoRepository.findById(toUuid(targetId)).orElseThrow()
                ResolvedTarget(todo.member) {
                    contentSnapshot(
                        title = todo.title,
                        body = todo.content,
                        contextType = AttachmentContextType.TODO,
                        contextId = targetId,
                    )
                }
            }
        }
    }

    private fun memberSnapshot(member: Member): String {
        val photo = if (member.hasProfilePhoto()) "있음" else "없음"
        return "이름: ${member.name}\n프로필 사진: $photo(version ${member.profilePhotoVersion})"
    }

    private fun contentSnapshot(
        title: String,
        body: String,
        contextType: AttachmentContextType,
        contextId: String,
    ): String {
        val attachments = attachmentRepository.findAllByContextTypeAndContextId(contextType, contextId)
            .sortedBy { it.orderIndex }
            .joinToString { it.originalFilename }
            .ifEmpty { "없음" }
        return "제목: $title\n내용: ${body.take(BODY_SNAPSHOT_LENGTH)}\n첨부: $attachments"
    }

    private fun toUuid(targetId: String): UUID {
        return runCatching { UUID.fromString(targetId) }.getOrNull() ?: notFound()
    }

    private fun notFound(): Nothing = throw NoSuchElementException("common.notFound")

    private class ResolvedTarget(
        val owner: Member,
        val scheduleVersion: Long? = null,
        val evidence: String? = null,
        val hasDelegatedChanges: Boolean = false,
        /** Deferred so the snapshot is assembled only once the report is known to be valid. */
        val snapshot: () -> String,
    )

    companion object {
        private const val BODY_SNAPSHOT_LENGTH = 300
    }

}
