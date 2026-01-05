package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
@Transactional
class ProfilePhotoService(
    private val attachmentRepository: AttachmentRepository,
    private val attachmentService: AttachmentService,
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun getProfilePhoto(memberId: Long): Attachment? {
        return attachmentRepository.findFirstByContextTypeAndContextId(
            contextType = AttachmentContextType.PROFILE,
            contextId = memberId.toString()
        )
    }

    @Transactional(readOnly = true)
    fun hasProfilePhoto(memberId: Long): Boolean {
        return attachmentRepository.existsByContextTypeAndContextId(
            contextType = AttachmentContextType.PROFILE,
            contextId = memberId.toString()
        )
    }

    @Transactional(readOnly = true)
    fun getMembersWithProfilePhoto(memberIds: List<Long>): Set<Long> {
        if (memberIds.isEmpty()) return emptySet()
        return attachmentRepository.findAllByContextTypeAndContextIdIn(
            contextType = AttachmentContextType.PROFILE,
            contextIds = memberIds.map { it.toString() }
        ).mapNotNull { it.contextId?.toLong() }.toSet()
    }

    fun setProfilePhoto(
        loginMember: LoginMember,
        sessionId: UUID,
        attachmentId: UUID
    ) {
        val contextId = loginMember.id.toString()

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.PROFILE,
            contextId = contextId,
            attachmentSessionId = sessionId,
            orderedAttachmentIds = listOf(attachmentId)
        )

        log.info("Profile photo set: memberId={}, attachmentId={}", loginMember.id, attachmentId)
    }

    fun deleteProfilePhoto(loginMember: LoginMember) {
        val contextId = loginMember.id.toString()

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.PROFILE,
            contextId = contextId,
            attachmentSessionId = null,
            orderedAttachmentIds = emptyList()
        )

        log.info("Profile photo deleted: memberId={}", loginMember.id)
    }
}
