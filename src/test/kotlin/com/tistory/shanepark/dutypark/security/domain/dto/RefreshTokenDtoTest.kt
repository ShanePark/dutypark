package com.tistory.shanepark.dutypark.security.domain.dto

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class RefreshTokenDtoTest {

    @Test
    fun `Ubuntu Linux Firefox should be detected as Linux`() {
        val ua = "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0"
        val result = RefreshTokenDto.UserAgent.of(ua)

        println("User Agent: $ua")
        println("OS: ${result?.os}")
        println("Browser: ${result?.browser}")
        println("Device: ${result?.device}")

        assertThat(result?.os).isEqualTo("Ubuntu")
        assertThat(result?.browser).isEqualTo("Firefox")
        assertThat(result?.device).isNotEqualTo("Other")
    }

    @Test
    fun `generic Linux Chrome should be detected`() {
        val ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        val result = RefreshTokenDto.UserAgent.of(ua)

        println("User Agent: $ua")
        println("OS: ${result?.os}")
        println("Browser: ${result?.browser}")
        println("Device: ${result?.device}")

        assertThat(result?.os).isEqualTo("Linux")
        assertThat(result?.browser).isEqualTo("Chrome")
    }

    @Test
    fun `Windows Chrome should be detected`() {
        val ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        val result = RefreshTokenDto.UserAgent.of(ua)

        println("User Agent: $ua")
        println("OS: ${result?.os}")
        println("Browser: ${result?.browser}")
        println("Device: ${result?.device}")

        assertThat(result?.os).isEqualTo("Windows NT")
        assertThat(result?.browser).isEqualTo("Chrome")
    }

    @Test
    fun `macOS Safari should be detected`() {
        val ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        val result = RefreshTokenDto.UserAgent.of(ua)

        println("User Agent: $ua")
        println("OS: ${result?.os}")
        println("Browser: ${result?.browser}")
        println("Device: ${result?.device}")

        assertThat(result?.os).isEqualTo("Mac OS")
        assertThat(result?.browser).isEqualTo("Safari")
    }

    @Test
    fun `iPhone Safari should be detected`() {
        val ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        val result = RefreshTokenDto.UserAgent.of(ua)

        println("User Agent: $ua")
        println("OS: ${result?.os}")
        println("Browser: ${result?.browser}")
        println("Device: ${result?.device}")

        assertThat(result?.os).isEqualTo("iOS")
        assertThat(result?.device).contains("iPhone")
    }
}
