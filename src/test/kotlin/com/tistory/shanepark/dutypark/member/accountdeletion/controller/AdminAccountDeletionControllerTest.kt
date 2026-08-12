package com.tistory.shanepark.dutypark.member.accountdeletion.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob
import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@AutoConfigureMockMvc
class AdminAccountDeletionControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var jobRepository: AccountDeletionJobRepository

    @Test
    fun `non-admin cannot retry failed deletion job`() {
        val job = saveFailedJob()

        mockMvc.perform(
            post("/admin/api/account-deletions/{jobId}/retry", job.id)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isUnauthorized)

        assertThat(jobRepository.findById(job.id!!).orElseThrow().status)
            .isEqualTo(AccountDeletionJobStatus.FAILED)
    }

    @Test
    fun `admin can retry failed deletion job`() {
        val job = saveFailedJob()

        mockMvc.perform(
            post("/admin/api/account-deletions/{jobId}/retry", job.id)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isAccepted)
            .andExpect(jsonPath("$.jobId").value(job.id))
            .andExpect(jsonPath("$.status").value("PENDING"))
            .andExpect(jsonPath("$.lastError").doesNotExist())

        val retried = jobRepository.findById(job.id!!).orElseThrow()
        assertThat(retried.status).isEqualTo(AccountDeletionJobStatus.PENDING)
        assertThat(retried.attemptCount).isZero()
        assertThat(retried.lockedAt).isNull()
        assertThat(retried.lastError).isNull()
        assertThat(retried.completedAt).isNull()
    }

    @Test
    fun `admin cannot retry non-failed deletion job`() {
        val job = savePendingJob()

        mockMvc.perform(
            post("/admin/api/account-deletions/{jobId}/retry", job.id)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.code").value("accountDeletion.job.retryNotAllowed"))

        assertThat(jobRepository.findById(job.id!!).orElseThrow().status)
            .isEqualTo(AccountDeletionJobStatus.PENDING)
    }

    @Test
    fun `admin receives not found for unknown deletion job`() {
        mockMvc.perform(
            post("/admin/api/account-deletions/{jobId}/retry", Long.MAX_VALUE)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isNotFound)
            .andExpect(jsonPath("$.code").value("accountDeletion.job.notFound"))
    }

    private fun saveFailedJob(): AccountDeletionJob {
        val job = savePendingJob()
        job.claim(Instant.parse("2026-08-12T00:01:00Z"))
        job.markFailed("sensitive failure detail")
        return jobRepository.saveAndFlush(job)
    }

    private fun savePendingJob(): AccountDeletionJob {
        return jobRepository.saveAndFlush(
            AccountDeletionJob(
                rootMemberId = TestData.member.id!!,
                nextAttemptAt = Instant.parse("2026-08-12T00:00:00Z"),
                createdAt = Instant.parse("2026-08-12T00:00:00Z"),
            )
        )
    }
}
