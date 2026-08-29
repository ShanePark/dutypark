package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob
import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionAcceptedResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionPreviewResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionStatusResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AuxiliaryAccountImpact
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.TeamAdminTransferCandidate
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.TeamDeletionImpact
import com.tistory.shanepark.dutypark.member.accountdeletion.exception.AccountDeletionException
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.reauth.ReauthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Service
@Transactional
class AccountDeletionService(
    private val memberRepository: MemberRepository,
    private val memberManagerRepository: MemberManagerRepository,
    private val memberSocialAccountRepository: MemberSocialAccountRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val teamRepository: TeamRepository,
    private val jobRepository: AccountDeletionJobRepository,
    private val reauthService: ReauthService,
    private val passwordEncoder: PasswordEncoder,
    private val jdbc: NamedParameterJdbcTemplate,
    private val clock: Clock,
) {

    @Transactional(readOnly = true)
    fun preview(login: LoginMember): AccountDeletionPreviewResponse {
        rejectImpersonation(login)
        val member = memberRepository.findMemberWithTeam(login.id).orElseThrow()
        val socialProviders = memberSocialAccountRepository.findAllByMemberIdIn(listOf(login.id))
            .map { it.provider }
            .distinct()
            .sortedBy { it.name }
        val auxiliaryTargets = discoverAutomaticTargets(member)
        return AccountDeletionPreviewResponse(
            hasPassword = !member.password.isNullOrBlank(),
            socialProviders = socialProviders,
            teamImpact = teamImpact(member),
            auxiliaryImpacts = auxiliaryTargets.map {
                AuxiliaryAccountImpact(
                    memberId = requireNotNull(it.id),
                    name = it.name,
                    willDelete = true,
                )
            },
        )
    }

    fun requestDeletion(login: LoginMember, request: AccountDeletionRequest): AccountDeletionAcceptedResponse {
        rejectImpersonation(login)
        if (request.confirmation != CONFIRMATION) {
            throw badRequest("account.delete.confirmationMismatch")
        }

        val receiptToken = request.receiptToken?.let(::validateReceiptToken)
            ?: AccountDeletionReceiptToken.generate()
        val receiptTokenHash = AccountDeletionReceiptToken.hash(receiptToken)

        jobRepository.findByRootMemberIdForUpdate(login.id).orElse(null)?.let { existing ->
            return acceptExistingJob(
                existing = existing,
                receiptToken = receiptToken,
                receiptTokenHash = receiptTokenHash,
                clientProvidedReceipt = request.receiptToken != null,
            )
        }

        val root = memberRepository.findMemberWithTeamForUpdate(login.id).orElseThrow()
        if (root.status != MemberStatus.ACTIVE) {
            // A concurrent deletion request can create the job after the initial lookup but
            // before this member lock is acquired. Re-read it with a lock so the caller's
            // receipt follows the same reconciliation rules as the fast path above.
            jobRepository.findByRootMemberIdForUpdate(login.id).orElse(null)?.let { existing ->
                return acceptExistingJob(
                    existing = existing,
                    receiptToken = receiptToken,
                    receiptTokenHash = receiptTokenHash,
                    clientProvidedReceipt = request.receiptToken != null,
                )
            }
            throw conflict("account.delete.alreadyPending")
        }
        reauthenticate(root, request)

        val targets = linkedSetOf(root)
        targets.addAll(discoverAutomaticTargets(root))
        targets.forEach { memberRepository.findMemberWithTeamForUpdate(requireNotNull(it.id)).orElseThrow() }

        val deleteTeamIds = linkedSetOf<Long>()
        var replacementMemberId: Long? = null
        targets.forEach { target ->
            val team = target.team ?: return@forEach
            val teamId = requireNotNull(team.id)
            val lockedTeam = teamRepository.findByIdForUpdate(teamId).orElseThrow()
            if (!lockedTeam.isAdmin(target.id)) return@forEach

            val activeMembers = lockedTeam.members.filter { it.status == MemberStatus.ACTIVE }
            if (activeMembers.size == 1 && activeMembers.single().id == target.id) {
                deleteTeamIds.add(teamId)
                return@forEach
            }
            if (target.id != root.id) {
                throw conflict("account.delete.auxiliaryTeamTransferRequired")
            }
            val replacementId = request.transferAdminToMemberId
                ?: throw conflict("account.delete.teamAdminTransferRequired")
            val replacement = activeMembers.singleOrNull { it.id == replacementId && it.id !in targets.map { m -> m.id } }
                ?: throw conflict("account.delete.teamAdminTransferInvalid")
            lockedTeam.changeAdmin(replacement)
            replacementMemberId = replacementId
        }

        val now = clock.instant()
        val job = AccountDeletionJob(
            rootMemberId = login.id,
            deleteTeamId = deleteTeamIds.singleOrNull(),
            replacementManagerId = replacementMemberId,
            nextAttemptAt = now,
            createdAt = now,
        )
        job.issueReceipt(
            receiptTokenHash = receiptTokenHash,
            estimatedCompletionAt = now.plus(EXPECTED_COMPLETION_TIME),
        )
        targets.forEach { job.addTargetMember(requireNotNull(it.id)) }
        deleteTeamIds.forEach(job::addTargetTeam)
        val saved = jobRepository.save(job)

        targets.forEach { target ->
            if (target.status == MemberStatus.ACTIVE) target.markDeletionPending(now)
        }
        invalidateAuthentication(targets.map { requireNotNull(it.id) }, targets)
        return accepted(saved, receiptToken)
    }

    /**
     * Looks up a deletion receipt without requiring the deleted account to remain authenticated.
     * An expired hash is cleared in the same transaction, while the job and its audit targets stay intact.
     */
    @Transactional(noRollbackFor = [AccountDeletionException::class])
    fun findStatus(receiptToken: String): AccountDeletionStatusResponse {
        val now = clock.instant()
        val receiptTokenHash = AccountDeletionReceiptToken.hash(receiptToken)
        val job = jobRepository.findByReceiptTokenHash(receiptTokenHash)
            .orElseThrow { receiptNotFound() }
        val expiresAt = job.receiptExpiresAt
        if (expiresAt != null && !expiresAt.isAfter(now)) {
            // Do not dirty-flush a stale entity here: a concurrent request may have
            // replaced this receipt after the lookup. The expected hash makes the clear
            // conditional on the value that actually expired.
            jobRepository.clearExpiredReceiptTokenHash(receiptTokenHash, now)
            throw receiptNotFound()
        }

        val status = when (job.status) {
            AccountDeletionJobStatus.PENDING,
            AccountDeletionJobStatus.RETRY_WAIT,
            AccountDeletionJobStatus.PROCESSING,
            -> "PROCESSING"

            AccountDeletionJobStatus.COMPLETED -> "COMPLETED"
            AccountDeletionJobStatus.FAILED -> "FAILED"
        }
        return AccountDeletionStatusResponse(
            status = status,
            estimatedCompletionAt = job.estimatedCompletionAt ?: job.createdAt.plus(EXPECTED_COMPLETION_TIME),
            completedAt = job.completedAt,
            receiptExpiresAt = if (status == "PROCESSING") null else job.receiptExpiresAt,
        )
    }

    private fun acceptExistingJob(
        existing: AccountDeletionJob,
        receiptToken: String,
        receiptTokenHash: String,
        clientProvidedReceipt: Boolean,
    ): AccountDeletionAcceptedResponse {
        when {
            existing.receiptTokenHash == receiptTokenHash -> Unit
            existing.receiptTokenHash == null || !clientProvidedReceipt -> {
                existing.issueReceipt(
                    receiptTokenHash = receiptTokenHash,
                    estimatedCompletionAt = existing.estimatedCompletionAt
                        ?: existing.createdAt.plus(EXPECTED_COMPLETION_TIME),
                    receiptIssuedAt = clock.instant(),
                )
            }
            else -> throw conflict("account.delete.receiptToken.mismatch")
        }
        return accepted(existing, receiptToken)
    }

    private fun reauthenticate(member: Member, request: AccountDeletionRequest) {
        val password = request.password?.takeIf { it.isNotBlank() }
        val proof = request.reauthProof?.takeIf { it.isNotBlank() }
        if ((password == null) == (proof == null)) {
            throw unauthorized("account.delete.reauthenticationFailed")
        }
        if (password != null) {
            val encoded = member.password
            if (encoded.isNullOrBlank() || !passwordEncoder.matches(password, encoded)) {
                throw unauthorized("account.delete.reauthenticationFailed")
            }
            return
        }
        try {
            reauthService.consume(requireNotNull(member.id), ReauthPurpose.DELETE_ACCOUNT, requireNotNull(proof))
        } catch (_: AuthException) {
            throw unauthorized("account.delete.reauthenticationFailed")
        }
    }

    private fun discoverAutomaticTargets(root: Member): List<Member> {
        val result = linkedMapOf<Long, Member>()
        val visited = mutableSetOf(requireNotNull(root.id))
        val queue = ArrayDeque<Member>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val manager = queue.removeFirst()
            memberManagerRepository.findAllByManager(manager).forEach { relation ->
                val candidate = relation.managed
                val candidateId = requireNotNull(candidate.id)
                if (!visited.add(candidateId)) return@forEach
                val hasSocial = memberSocialAccountRepository.findAllByMemberIdIn(listOf(candidateId)).isNotEmpty()
                val isAuthenticationFree = candidate.email == null && candidate.password == null && !hasSocial
                val isSoleManager = memberManagerRepository.findAllByManaged(candidate)
                    .mapNotNull { it.manager.id }
                    .distinct()
                    .singleOrNull() == manager.id
                if (candidate.status == MemberStatus.ACTIVE && isAuthenticationFree && isSoleManager) {
                    result[candidateId] = candidate
                    queue.add(candidate)
                }
            }
        }
        return result.values.toList()
    }

    private fun teamImpact(member: Member): TeamDeletionImpact? {
        val team = member.team ?: return null
        val activeMembers = team.members.filter { it.status == MemberStatus.ACTIVE }
        val isAdmin = team.isAdmin(member.id)
        return TeamDeletionImpact(
            teamId = requireNotNull(team.id),
            teamName = team.name,
            isAdmin = isAdmin,
            activeMemberCount = activeMembers.size,
            willDeleteTeam = isAdmin && activeMembers.size == 1,
            transferCandidates = if (!isAdmin) emptyList() else activeMembers
                .filterNot { it.id == member.id }
                .map { TeamAdminTransferCandidate(requireNotNull(it.id), it.name) },
        )
    }

    private fun invalidateAuthentication(memberIds: List<Long>, members: Collection<Member>) {
        refreshTokenRepository.deleteAll(refreshTokenRepository.findAllByMemberIdIn(memberIds))
        jdbc.update(
            "delete from mobile_oauth_transaction where link_member_id in (:ids) or member_id in (:ids)",
            MapSqlParameterSource("ids", memberIds),
        )
        members.mapNotNull { it.email }.distinct().forEach { email ->
            jdbc.update("delete from login_attempt where email = :email", mapOf("email" to email))
        }
    }

    private fun rejectImpersonation(login: LoginMember) {
        if (login.isImpersonating) throw forbidden("account.delete.impersonationForbidden")
    }

    private fun accepted(job: AccountDeletionJob, receiptToken: String? = null) = AccountDeletionAcceptedResponse(
        jobId = requireNotNull(job.id),
        status = if (job.status == AccountDeletionJobStatus.COMPLETED) "COMPLETED" else "ACCEPTED",
        receiptToken = receiptToken,
        estimatedCompletionAt = job.estimatedCompletionAt ?: job.createdAt.plus(EXPECTED_COMPLETION_TIME),
    )

    private fun badRequest(code: String) = AccountDeletionException(code, 400)
    private fun unauthorized(code: String) = AccountDeletionException(code, 401)
    private fun forbidden(code: String) = AccountDeletionException(code, 403)
    private fun conflict(code: String) = AccountDeletionException(code, 409)
    private fun receiptNotFound() = AccountDeletionException("accountDeletion.receipt.notFound", 404)

    private fun validateReceiptToken(receiptToken: String): String {
        if (!AccountDeletionReceiptToken.isValid(receiptToken)) {
            throw badRequest("account.delete.receiptToken.invalid")
        }
        return receiptToken
    }

    companion object {
        private const val CONFIRMATION = "DELETE"
        private val EXPECTED_COMPLETION_TIME: Duration = Duration.ofMinutes(5)
    }
}
