package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.config.LocalizedMessageResolver
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import org.junit.jupiter.api.AfterEach
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.context.support.StaticMessageSource
import org.springframework.context.i18n.LocaleContextHolder
import java.util.Locale

class RestExceptionControllerAdviceTest {

    private val messageSource = StaticMessageSource().apply {
        addMessage("auth.login.failed", Locale.KOREAN, "이메일 또는 비밀번호가 올바르지 않습니다.")
        addMessage("auth.login.failed", Locale.ENGLISH, "Email or password is incorrect.")
        addMessage("common.notFound.title", Locale.KOREAN, "찾을 수 없음")
        addMessage("common.notFound.title", Locale.ENGLISH, "Not Found")
        addMessage("common.notFound.message", Locale.KOREAN, "리소스를 찾을 수 없습니다.")
        addMessage("common.notFound.message", Locale.ENGLISH, "Resource not found.")
        addMessage("member.notFound", Locale.KOREAN, "회원을 찾을 수 없습니다.")
        addMessage("member.notFound", Locale.ENGLISH, "Member not found.")
    }

    private val advice = RestExceptionControllerAdvice(LocalizedMessageResolver(messageSource))

    @AfterEach
    fun clearLocaleContext() {
        LocaleContextHolder.resetLocaleContext()
    }

    @Test
    fun `notAuthorizedHandler builds localized error response`() {
        LocaleContextHolder.setLocale(Locale.ENGLISH)
        val response = advice.notAuthorizedHandler(AuthException("auth.login.failed"))

        assertThat(response.statusCode.value()).isEqualTo(401)
        assertThat(response.body?.errorCode).isEqualTo(401)
        assertThat(response.body?.message).isEqualTo("Email or password is incorrect.")
    }

    @Test
    fun `noSuchElementHandler uses localized exception code when present`() {
        LocaleContextHolder.setLocale(Locale.KOREAN)
        val response = advice.noSuchElementHandler(NoSuchElementException("member.notFound"))

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.get("error")).isEqualTo("찾을 수 없음")
        assertThat(response.body?.get("message")).isEqualTo("회원을 찾을 수 없습니다.")
    }

    @Test
    fun `noSuchElementHandler falls back to default message when missing`() {
        LocaleContextHolder.setLocale(Locale.ENGLISH)
        val response = advice.noSuchElementHandler(NoSuchElementException())

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.get("message")).isEqualTo("Resource not found.")
    }
}
