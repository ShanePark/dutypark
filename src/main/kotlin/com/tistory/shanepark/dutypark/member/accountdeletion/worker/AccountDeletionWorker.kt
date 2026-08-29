package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetMemberRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetTeamRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionExternalAccountRevoker
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Component
class AccountDeletionWorker(
    private val coordinator: AccountDeletionJobCoordinator,
    private val targetMemberRepository: AccountDeletionTargetMemberRepository,
    private val targetTeamRepository: AccountDeletionTargetTeamRepository,
    private val externalAccountRevoker: AccountDeletionExternalAccountRevoker,
    private val fileCleaner: AccountDeletionFileCleaner,
    private val databaseCleaner: AccountDeletionDatabaseCleaner,
) {
    private val log = logger()

    @Scheduled(
        fixedDelayString = "\${dutypark.account-deletion.worker.fixed-delay-ms:5000}",
        initialDelayString = "\${dutypark.account-deletion.worker.initial-delay-ms:5000}",
    )
    fun processPendingJobs() {
        coordinator.clearExpiredReceiptTokenHashes()
        while (true) {
            val claim = coordinator.claimNext() ?: return
            runCatching { process(claim) }
                .onFailure { error ->
                    val code = "accountDeletion.worker.${error::class.simpleName ?: "failure"}"
                    log.error("Account deletion job failed: jobId={}, errorCode={}", claim.jobId, code)
                    runCatching { coordinator.markFailure(claim, code) }
                        .onFailure { log.error("Account deletion job state update failed: jobId={}", claim.jobId) }
                }
        }
    }

    private fun process(claim: AccountDeletionClaim) {
        val memberIds = targetMemberRepository.findAllByJobId(claim.jobId).map { it.memberId }
        val teamIds = targetTeamRepository.findAllByJobId(claim.jobId).map { it.teamId }
        check(memberIds.isNotEmpty())
        externalAccountRevoker.revoke(memberIds)
        fileCleaner.deleteFiles(memberIds, teamIds)
        databaseCleaner.clean(memberIds, teamIds)
        if (coordinator.markCompleted(claim)) {
            log.info(
                "Account deletion job completed: jobId={}, memberCount={}, teamCount={}",
                claim.jobId,
                memberIds.size,
                teamIds.size,
            )
        }
    }
}
