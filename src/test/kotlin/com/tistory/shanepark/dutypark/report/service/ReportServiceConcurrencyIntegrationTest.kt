package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.RepeatedTest
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.support.TransactionTemplate
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit

@SpringBootTest
class ReportServiceConcurrencyIntegrationTest {

    @Autowired lateinit var reportService: ReportService
    @Autowired lateinit var contentReportRepository: ContentReportRepository
    @Autowired lateinit var memberRepository: MemberRepository
    @Autowired lateinit var transactionTemplate: TransactionTemplate

    @RepeatedTest(5)
    fun `concurrent duplicate reports return one open report id`() {
        val suffix = System.nanoTime().toString().takeLast(12)
        val (reporterId, reportedId) = transactionTemplate.execute {
            val reporter = memberRepository.saveAndFlush(Member("신고자", "reporter-$suffix@duty.park", "pass"))
            val reported = memberRepository.saveAndFlush(Member("신고대상", "reported-$suffix@duty.park", "pass"))
            requireNotNull(reporter.id) to requireNotNull(reported.id)
        }
        val request = CreateReportRequest(
            targetType = ReportTargetType.MEMBER,
            targetId = reportedId.toString(),
            reason = ReportReason.IMPERSONATION,
        )

        try {
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            val futures: List<Future<ReportCreateResult>> = List(2) {
                executor.submit(Callable {
                    start.await()
                    reportService.createReport(reporterId, request)
                })
            }
            val results = try {
                start.countDown()
                futures.map { it.get(10, TimeUnit.SECONDS) }
            } finally {
                futures.filterNot { it.isDone }.forEach { it.cancel(true) }
                executor.shutdownNow()
                executor.awaitTermination(5, TimeUnit.SECONDS)
            }

            assertThat(results.map { it.id }.distinct()).hasSize(1)
            assertThat(results.count { it.isNew }).isEqualTo(1)
            val persistedReportIds = transactionTemplate.execute {
                contentReportRepository.findAll().filter {
                    it.reporter?.id == reporterId &&
                        it.targetType == request.targetType &&
                        it.targetId == request.targetId
                }.map { it.id }
            }
            assertThat(persistedReportIds).hasSize(1)
        } finally {
            transactionTemplate.execute {
                contentReportRepository.deleteAll(
                    contentReportRepository.findAll().filter {
                        it.reporter?.id == reporterId || it.reportedMember?.id == reportedId
                    }
                )
                contentReportRepository.flush()
                memberRepository.deleteAllById(listOf(reporterId, reportedId))
                memberRepository.flush()
            }
        }
    }
}
