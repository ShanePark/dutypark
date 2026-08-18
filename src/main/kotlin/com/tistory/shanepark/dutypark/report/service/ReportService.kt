package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class ReportService(
    private val contentReportRepository: ContentReportRepository,
    private val memberRepository: MemberRepository,
    private val scheduleRepository: ScheduleRepository,
    private val todoRepository: TodoRepository,
    private val attachmentRepository: AttachmentRepository,
    private val blockService: BlockService,
) {

    /**
     * Reporting does not check whether the reporter can still see the target:
     * a member must stay able to report content of somebody they already blocked.
     */
    @SlackNotification
    fun createReport(loginMemberId: Long, request: CreateReportRequest): ReportCreateResult {
        if (request.reason == ReportReason.OTHER && request.detail.isNullOrBlank()) {
            throw BadRequestException("report.detail.required")
        }

        val reporter = memberRepository.findById(loginMemberId).orElseThrow()
        val target = resolveTarget(request.targetType, request.targetId)
        val owner = target.owner
        if (owner.id == reporter.id) {
            throw BadRequestException("report.self")
        }

        val result = existingOpenReport(loginMemberId, request)
            ?.let { ReportCreateResult(id = it.id, isNew = false) }
            ?: ReportCreateResult(id = saveReport(reporter, owner, target, request).id, isNew = true)

        if (request.alsoBlock) {
            blockService.block(reporter.id!!, owner.id!!)
        }

        return result
    }

    private fun existingOpenReport(reporterId: Long, request: CreateReportRequest): ContentReport? {
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
                reportedMember = owner,
                targetType = request.targetType,
                targetId = request.targetId,
                reason = request.reason,
                detail = request.detail,
                contentSnapshot = target.snapshot(),
                reporterName = reporter.name,
                reportedMemberName = owner.name,
            )
        )
    }

    private fun resolveTarget(targetType: ReportTargetType, targetId: String): ResolvedTarget {
        return when (targetType) {
            ReportTargetType.MEMBER -> {
                val member = memberRepository.findById(targetId.toLongOrNull() ?: notFound()).orElseThrow()
                ResolvedTarget(member) { memberSnapshot(member) }
            }

            ReportTargetType.SCHEDULE -> {
                val schedule = scheduleRepository.findById(toUuid(targetId)).orElseThrow()
                ResolvedTarget(schedule.member) {
                    contentSnapshot(
                        title = schedule.content,
                        body = schedule.description,
                        contextType = AttachmentContextType.SCHEDULE,
                        contextId = targetId,
                    )
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
        /** Deferred so the snapshot is assembled only once the report is known to be valid. */
        val snapshot: () -> String,
    )

    companion object {
        private const val BODY_SNAPSHOT_LENGTH = 300
    }

}
