package com.tistory.shanepark.dutypark.member.accountdeletion.controller

import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionAcceptedResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionPreviewResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/members/me/deletion")
class AccountDeletionController(
    private val accountDeletionService: AccountDeletionService,
    private val cookieService: CookieService,
) {
    @GetMapping
    fun preview(@Login login: LoginMember): AccountDeletionPreviewResponse = accountDeletionService.preview(login)

    @PostMapping
    fun requestDeletion(
        @Login login: LoginMember,
        @RequestBody request: AccountDeletionRequest,
        response: HttpServletResponse,
    ): ResponseEntity<AccountDeletionAcceptedResponse> {
        val accepted = accountDeletionService.requestDeletion(login, request)
        cookieService.clearTokenCookies(response)
        return ResponseEntity.accepted()
            .cacheControl(CacheControl.noStore())
            .body(accepted)
    }
}
