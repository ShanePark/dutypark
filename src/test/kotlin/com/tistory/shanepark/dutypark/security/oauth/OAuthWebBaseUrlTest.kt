package com.tistory.shanepark.dutypark.security.oauth

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class OAuthWebBaseUrlTest {

    @Test
    fun `null cookie domain uses local backend origin`() {
        val baseUrl = OAuthWebBaseUrl(CookieConfig(domain = null))

        assertThat(baseUrl.origin).isEqualTo("http://localhost:8080")
    }

    @Test
    fun `blank cookie domain uses local backend origin`() {
        val baseUrl = OAuthWebBaseUrl(CookieConfig(domain = "  "))

        assertThat(baseUrl.origin).isEqualTo("http://localhost:8080")
    }

    @Test
    fun `production cookie domain becomes https backend origin`() {
        val baseUrl = OAuthWebBaseUrl(CookieConfig(domain = "dutypark.o-r.kr"))

        assertThat(baseUrl.origin).isEqualTo("https://dutypark.o-r.kr")
    }

    @Test
    fun `cookie domain is normalized before building backend origin`() {
        val baseUrl = OAuthWebBaseUrl(CookieConfig(domain = ".DutyPark.O-R.KR."))

        assertThat(baseUrl.origin).isEqualTo("https://dutypark.o-r.kr")
    }
}
