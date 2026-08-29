package com.tistory.shanepark.dutypark.member.accountdeletion.controller

import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionStatusRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionStatusResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionService
import jakarta.validation.Valid
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/account-deletions")
class AccountDeletionStatusController(
    private val accountDeletionService: AccountDeletionService,
) {
    @PostMapping("/status")
    fun status(
        @Valid @RequestBody request: AccountDeletionStatusRequest,
    ): ResponseEntity<AccountDeletionStatusResponse> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(accountDeletionService.findStatus(request.receiptToken))
}
