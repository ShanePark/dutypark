package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.scheduling.annotation.Scheduled

class AccountDeletionWorkerSchedulingTest {

    @Test
    fun `worker uses five second defaults when scheduling properties are absent`() {
        val scheduled = AccountDeletionWorker::class.java
            .getDeclaredMethod("processPendingJobs")
            .getAnnotation(Scheduled::class.java)

        assertThat(scheduled.fixedDelayString)
            .isEqualTo("\${dutypark.account-deletion.worker.fixed-delay-ms:5000}")
        assertThat(scheduled.initialDelayString)
            .isEqualTo("\${dutypark.account-deletion.worker.initial-delay-ms:5000}")
    }
}
