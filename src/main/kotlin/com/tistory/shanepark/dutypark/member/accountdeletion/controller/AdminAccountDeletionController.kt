package com.tistory.shanepark.dutypark.member.accountdeletion.controller

import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRetryResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AdminAccountDeletionService
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/admin/api/account-deletions")
class AdminAccountDeletionController(
    private val adminAccountDeletionService: AdminAccountDeletionService,
) {
    @PostMapping("/{jobId}/retry")
    fun retryFailed(@PathVariable jobId: Long): ResponseEntity<AccountDeletionRetryResponse> {
        return ResponseEntity.accepted().body(adminAccountDeletionService.retryFailed(jobId))
    }
}
