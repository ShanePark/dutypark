package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.attachment.exception.AttachmentExtensionBlockedException
import com.tistory.shanepark.dutypark.attachment.exception.AttachmentTooLargeException
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.core.MethodParameter
import org.springframework.dao.CannotAcquireLockException
import org.springframework.validation.BeanPropertyBindingResult
import org.springframework.validation.FieldError
import org.springframework.web.bind.MethodArgumentNotValidException

class RestExceptionControllerAdviceTest {

    private val advice = RestExceptionControllerAdvice()

    @Test
    fun `dutyparkExceptionHandler returns code-based response`() {
        val response = advice.dutyparkExceptionHandler(AuthException("auth.login.failed"))

        assertThat(response.statusCode.value()).isEqualTo(401)
        assertThat(response.body?.status).isEqualTo(401)
        assertThat(response.body?.code).isEqualTo("auth.login.failed")
        assertThat(response.body?.details).isNull()
        assertThat(response.body?.fieldErrors).isEmpty()
    }

    @Test
    fun `dutyparkExceptionHandler preserves bad request codes`() {
        val response = advice.dutyparkExceptionHandler(BadRequestException("friend.family.notFriend"))

        assertThat(response.statusCode.value()).isEqualTo(400)
        assertThat(response.body?.status).isEqualTo(400)
        assertThat(response.body?.code).isEqualTo("friend.family.notFriend")
    }

    @Test
    fun `noSuchElementHandler keeps explicit code`() {
        val response = advice.noSuchElementHandler(NoSuchElementException("member.notFound"))

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.code).isEqualTo("member.notFound")
    }

    @Test
    fun `noSuchElementHandler falls back to common notFound`() {
        val response = advice.noSuchElementHandler(NoSuchElementException())

        assertThat(response.statusCode.value()).isEqualTo(404)
        assertThat(response.body?.code).isEqualTo("common.notFound")
    }

    @Test
    fun `illegalArgumentHandler falls back to common badRequest for non-code messages`() {
        val response = advice.illegalArgumentHandler(IllegalArgumentException("Callback URL is required"))

        assertThat(response.statusCode.value()).isEqualTo(400)
        assertThat(response.body?.code).isEqualTo("common.badRequest")
    }

    @Test
    fun `illegalArgumentHandler keeps camelCase error codes`() {
        val response = advice.illegalArgumentHandler(IllegalArgumentException("dutyBatch.template.required"))

        assertThat(response.statusCode.value()).isEqualTo(400)
        assertThat(response.body?.code).isEqualTo("dutyBatch.template.required")
    }

    @Test
    fun `attachment exceptions return code-only responses with matching status`() {
        val blocked = advice.dutyparkExceptionHandler(
            AttachmentExtensionBlockedException(filename = "virus.exe", extension = ".exe"),
        )
        val tooLarge = advice.dutyparkExceptionHandler(
            AttachmentTooLargeException(filename = "large.png", size = 10_000_000, maxSize = 5_000_000),
        )

        assertThat(blocked.statusCode.value()).isEqualTo(400)
        assertThat(blocked.body?.code).isEqualTo("attachment.extension.blocked")
        assertThat(tooLarge.statusCode.value()).isEqualTo(413)
        assertThat(tooLarge.body?.code).isEqualTo("attachment.size.exceeded")
    }

    @Test
    fun `lock contention returns retryable conflict code`() {
        val response = advice.concurrentUpdateHandler(CannotAcquireLockException("member is busy"))

        assertThat(response.statusCode.value()).isEqualTo(409)
        assertThat(response.body?.status).isEqualTo(409)
        assertThat(response.body?.code).isEqualTo("common.concurrentUpdate")
    }

    @Test
    fun `methodArgumentNotValidHandler returns normalized field errors`() {
        val bindingResult = BeanPropertyBindingResult(Any(), "request")
        bindingResult.addError(FieldError("request", "name", "team.name.required"))
        bindingResult.addError(FieldError("request", "description", "must not be blank"))
        val exception = MethodArgumentNotValidException(dummyMethodParameter(), bindingResult)

        val response = advice.methodArgumentNotValidHandler(exception)

        assertThat(response.statusCode.value()).isEqualTo(400)
        assertThat(response.body?.code).isEqualTo("team.name.required")
        assertThat(response.body?.fieldErrors).containsExactly(
            com.tistory.shanepark.dutypark.common.domain.dto.DutyParkFieldError(
                field = "name",
                code = "team.name.required",
            ),
            com.tistory.shanepark.dutypark.common.domain.dto.DutyParkFieldError(
                field = "description",
                code = "common.validation.failed",
            ),
        )
    }

    @Suppress("unused")
    private fun dummyRequest(name: String) {
    }

    private fun dummyMethodParameter(): MethodParameter {
        val method = this::class.java.getDeclaredMethod("dummyRequest", String::class.java)
        return MethodParameter(method, 0)
    }
}
