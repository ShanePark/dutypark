package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
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
                    log.error(
                        "Account deletion job failed: {}",
                        auditContext(
                            mapOf(
                                "event" to "account_deletion_job_failed",
                                "jobId" to claim.jobId,
                                "errorCode" to code,
                                "causeTypes" to causeTypes(error),
                                "stackFrames" to safeStackFrames(error),
                            )
                        ),
                    )
                    runCatching { coordinator.markFailure(claim, code) }
                        .onFailure { updateError ->
                            log.error(
                                "Account deletion job failure state update failed: {}",
                                auditContext(
                                    mapOf(
                                        "event" to "account_deletion_failure_state_update_failed",
                                        "jobId" to claim.jobId,
                                        "errorType" to updateError.javaClass.simpleName,
                                        "causeTypes" to causeTypes(updateError),
                                        "stackFrames" to safeStackFrames(updateError),
                                    )
                                ),
                            )
                        }
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
            log.auditEventAfterCommit(
                event = "account_deletion_job_completed",
                actor = null,
                target = mapOf("jobId" to claim.jobId),
                details = mapOf("memberCount" to memberIds.size, "teamCount" to teamIds.size),
            )
        }
    }

    private fun causeTypes(error: Throwable): List<String> =
        generateSequence(error) { it.cause }.take(5).map { it.javaClass.simpleName }.toList()

    private fun safeStackFrames(error: Throwable): List<String> =
        generateSequence(error) { it.cause }
            .take(5)
            .flatMap { cause ->
                cause.stackTrace.take(8).asSequence().map { frame ->
                    "${frame.className}.${frame.methodName}:${frame.lineNumber}"
                }
            }
            .take(24)
            .toList()
}
