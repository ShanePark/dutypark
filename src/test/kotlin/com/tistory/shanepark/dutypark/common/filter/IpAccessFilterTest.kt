package com.tistory.shanepark.dutypark.common.filter

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

internal class IpAccessFilterTest {

    @Test
    fun regexTest() {
        val ipAccessFilter = IpAccessFilter()

        assertThat(ipAccessFilter.isValidRequest("123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isValidRequest("192.168.123.55")).isTrue()
        assertThat(ipAccessFilter.isValidRequest("172.1.123.55")).isTrue()
        assertThat(ipAccessFilter.isValidRequest("http://123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isValidRequest("https://123.123.123.55:8080/")).isFalse
        assertThat(ipAccessFilter.isValidRequest("http://123.123.123.55")).isFalse
        assertThat(ipAccessFilter.isValidRequest("http://localhost:8080/")).isTrue
        assertThat(ipAccessFilter.isValidRequest("http://localhost:8080")).isTrue
        assertThat(ipAccessFilter.isValidRequest("https://localhost:8080")).isTrue
        assertThat(ipAccessFilter.isValidRequest("http://dutypark.kr")).isTrue
        assertThat(ipAccessFilter.isValidRequest("https://dutypark.kr")).isTrue
        assertThat(ipAccessFilter.isValidRequest("https://dutypark.kr/")).isTrue
    }

}


