package com.tistory.shanepark.dutypark.member.accountdeletion.dto

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant

data class AccountDeletionPreviewResponse(
    val hasPassword: Boolean,
    val socialProviders: List<SsoType>,
    val teamImpact: TeamDeletionImpact?,
    val auxiliaryImpacts: List<AuxiliaryAccountImpact>,
)

data class TeamDeletionImpact(
    val teamId: Long,
    val teamName: String,
    val isAdmin: Boolean,
    val activeMemberCount: Int,
    val willDeleteTeam: Boolean,
    val transferCandidates: List<TeamAdminTransferCandidate>,
)

data class TeamAdminTransferCandidate(
    val memberId: Long,
    val name: String,
)

data class AuxiliaryAccountImpact(
    val memberId: Long,
    val name: String,
    val willDelete: Boolean,
)

data class AccountDeletionRequest(
    val confirmation: String,
    val password: String? = null,
    val reauthProof: String? = null,
    val transferAdminToMemberId: Long? = null,
    val receiptToken: String? = null,
)

data class AccountDeletionAcceptedResponse(
    val jobId: Long,
    val status: String,
    val receiptToken: String? = null,
    val estimatedCompletionAt: Instant? = null,
)

data class AccountDeletionStatusRequest(
    @field:NotBlank
    @field:Size(max = 512)
    val receiptToken: String,
)

data class AccountDeletionStatusResponse(
    val status: String,
    val estimatedCompletionAt: Instant,
    val completedAt: Instant?,
    val receiptExpiresAt: Instant?,
)
