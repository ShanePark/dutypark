package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.dto.ProfilePhotoResponse
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
    fun getProfilePhotoUrl(memberId: Long): String? {
        val attachment = getProfilePhoto(memberId) ?: return null
        return buildThumbnailUrl(attachment.id)
    }

    @Transactional(readOnly = true)
    fun getProfilePhotoUrls(memberIds: List<Long>): Map<Long, String?> {
        if (memberIds.isEmpty()) return emptyMap()

        val contextIds = memberIds.map { it.toString() }
        val attachments = attachmentRepository.findAllByContextTypeAndContextIdIn(
            contextType = AttachmentContextType.PROFILE,
            contextIds = contextIds
        )

        val attachmentByContextId = attachments.associateBy { it.contextId }

        return memberIds.associateWith { memberId ->
            attachmentByContextId[memberId.toString()]?.let { buildThumbnailUrl(it.id) }
        }
    }

    fun setProfilePhoto(
        loginMember: LoginMember,
        sessionId: UUID,
        attachmentId: UUID
    ): ProfilePhotoResponse {
        val contextId = loginMember.id.toString()

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = AttachmentContextType.PROFILE,
            contextId = contextId,
            attachmentSessionId = sessionId,
            orderedAttachmentIds = listOf(attachmentId)
        )

        log.info("Profile photo set: memberId={}, attachmentId={}", loginMember.id, attachmentId)

        val profilePhotoUrl = getProfilePhotoUrl(loginMember.id)
        return ProfilePhotoResponse(profilePhotoUrl = profilePhotoUrl)
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

    private fun buildThumbnailUrl(attachmentId: UUID): String {
        return "/api/attachments/$attachmentId/thumbnail"
    }
}
