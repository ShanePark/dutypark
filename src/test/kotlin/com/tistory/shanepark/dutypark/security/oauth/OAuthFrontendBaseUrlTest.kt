package com.tistory.shanepark.dutypark.security.oauth

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class OAuthFrontendBaseUrlTest {

    @Test
    fun `null cookie domain uses local frontend origin`() {
        val baseUrl = OAuthFrontendBaseUrl(CookieConfig(domain = null))

        assertThat(baseUrl.origin).isEqualTo("http://localhost:5173")
    }

    @Test
    fun `blank cookie domain uses local frontend origin`() {
        val baseUrl = OAuthFrontendBaseUrl(CookieConfig(domain = "  "))

        assertThat(baseUrl.origin).isEqualTo("http://localhost:5173")
    }

    @Test
    fun `production cookie domain becomes https frontend origin`() {
        val baseUrl = OAuthFrontendBaseUrl(CookieConfig(domain = "dutypark.o-r.kr"))

        assertThat(baseUrl.origin).isEqualTo("https://dutypark.o-r.kr")
    }

    @Test
    fun `cookie domain is normalized before building frontend origin`() {
        val baseUrl = OAuthFrontendBaseUrl(CookieConfig(domain = ".DutyPark.O-R.KR."))

        assertThat(baseUrl.origin).isEqualTo("https://dutypark.o-r.kr")
    }
}
