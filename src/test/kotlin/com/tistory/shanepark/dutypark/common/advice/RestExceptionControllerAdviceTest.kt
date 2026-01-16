package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class RestExceptionControllerAdviceTest {

    private val advice = RestExceptionControllerAdvice()

    @Test
    fun `notAuthorizedHandler builds error response`() {
        val response = advice.notAuthorizedHandler(AuthException("nope"))

        assertThat(response.statusCode.value()).isEqualTo(401)
        assertThat(response.body?.errorCode).isEqualTo(401)
        assertThat(response.body?.message).isEqualTo("nope")
    }

    @Test
    fun `noSuchElementHandler uses exception message when present`() {
        val response = advice.noSuchElementHandler(NoSuchElementException("missing"))

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.get("message")).isEqualTo("missing")
    }

    @Test
    fun `noSuchElementHandler falls back to default message when missing`() {
        val response = advice.noSuchElementHandler(NoSuchElementException())

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.get("message")).isEqualTo("Resource not found")
    }
}
