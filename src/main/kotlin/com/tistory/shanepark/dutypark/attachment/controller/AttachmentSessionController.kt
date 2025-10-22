package com.tistory.shanepark.dutypark.attachment.controller

import com.tistory.shanepark.dutypark.attachment.dto.CreateSessionRequest
import com.tistory.shanepark.dutypark.attachment.dto.CreateSessionResponse
import com.tistory.shanepark.dutypark.attachment.service.AttachmentUploadSessionService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/attachments/sessions")
class AttachmentSessionController(
    private val sessionService: AttachmentUploadSessionService
) {

    @PostMapping
    fun createSession(
        @Login loginMember: LoginMember,
        @RequestBody request: CreateSessionRequest
    ): CreateSessionResponse {
        val session = sessionService.createSession(
            loginMember = loginMember,
            contextType = request.contextType,
            targetContextId = request.targetContextId
        )
        return CreateSessionResponse.from(session)
    }
}
