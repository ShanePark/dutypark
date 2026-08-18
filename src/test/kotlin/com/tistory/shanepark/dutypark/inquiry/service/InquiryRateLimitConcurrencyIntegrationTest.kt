package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.InquiryRateLimitLock
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRateLimitLockRepository
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@SpringBootTest
class InquiryRateLimitConcurrencyIntegrationTest {

    @Autowired
    lateinit var inquiryService: InquiryService

    @Autowired
    lateinit var inquiryRepository: InquiryRepository

    @Autowired
    lateinit var rateLimitLockRepository: InquiryRateLimitLockRepository

    @Test
    fun `concurrent inquiries from one ip never exceed the quota`() {
        val ipAddress = "198.51.100.${System.nanoTime().toString().takeLast(3)}"
        rateLimitLockRepository.saveAllAndFlush((0 until 256).map(::InquiryRateLimitLock))
        val start = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(20)
        val futures = List(20) { index ->
            executor.submit<Boolean> {
                start.await()
                try {
                    inquiryService.createInquiry(
                        memberId = null,
                        request = CreateInquiryRequest(
                            email = "guest@dutypark.o-r.kr",
                            subject = null,
                            content = "concurrent inquiry $index",
                        ),
                        ipAddress = ipAddress,
                    )
                    true
                } catch (_: RateLimitException) {
                    false
                }
            }
        }

        try {
            start.countDown()
            val accepted = futures.count { it.get(15, TimeUnit.SECONDS) }

            assertThat(accepted).isEqualTo(5)
            assertThat(inquiryRepository.findAll().count { it.ipAddress == ipAddress }).isEqualTo(5)
        } finally {
            futures.filterNot { it.isDone }.forEach { it.cancel(true) }
            executor.shutdownNow()
            executor.awaitTermination(5, TimeUnit.SECONDS)
            inquiryRepository.deleteAll(inquiryRepository.findAll().filter { it.ipAddress == ipAddress })
        }
    }
}
