package com.tistory.shanepark.dutypark.team.domain.enums

import org.assertj.core.api.Assertions.assertThatCode
import org.junit.jupiter.api.Test

class WorkTypeTest {

    @Test
    fun `WorkType includes WEEKEND and FIXED`() {
        assertThatCode { WorkType.valueOf("WEEKEND") }.doesNotThrowAnyException()
        assertThatCode { WorkType.valueOf("FIXED") }.doesNotThrowAnyException()
    }
}
