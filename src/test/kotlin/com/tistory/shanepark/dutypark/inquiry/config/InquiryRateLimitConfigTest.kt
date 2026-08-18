package com.tistory.shanepark.dutypark.inquiry.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class InquiryRateLimitConfigTest {

    @Test
    fun `default hourly limit is five`() {
        assertThat(InquiryRateLimitConfig().maxPerHour).isEqualTo(5)
    }
}
