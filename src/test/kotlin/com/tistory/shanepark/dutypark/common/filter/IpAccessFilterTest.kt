package com.tistory.shanepark.dutypark.common.filter

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

internal class IpAccessFilterTest {

    @Test
    fun regexTest() {
        val ipAccessFilter = IpAccessFilter()

        assertThat(ipAccessFilter.isNotIpPattern("123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isNotIpPattern("http://123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isNotIpPattern("https://123.123.123.55:8080/")).isFalse
        assertThat(ipAccessFilter.isNotIpPattern("http://123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isNotIpPattern("http://localhost:8080/")).isTrue
        assertThat(ipAccessFilter.isNotIpPattern("http://localhost:8080")).isTrue
        assertThat(ipAccessFilter.isNotIpPattern("https://localhost:8080")).isTrue
        assertThat(ipAccessFilter.isNotIpPattern("http://dutypark.o-r.kr")).isTrue
        assertThat(ipAccessFilter.isNotIpPattern("https://dutypark.o-r.kr")).isTrue
        assertThat(ipAccessFilter.isNotIpPattern("https://dutypark.o-r.kr/")).isTrue
    }

}


