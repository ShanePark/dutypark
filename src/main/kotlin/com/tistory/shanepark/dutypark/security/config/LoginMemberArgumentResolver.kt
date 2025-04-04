package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.core.MethodParameter
import org.springframework.web.bind.support.WebDataBinderFactory
import org.springframework.web.context.request.NativeWebRequest
import org.springframework.web.context.request.RequestAttributes
import org.springframework.web.method.support.HandlerMethodArgumentResolver
import org.springframework.web.method.support.ModelAndViewContainer

class LoginMemberArgumentResolver : HandlerMethodArgumentResolver {

    override fun supportsParameter(parameter: MethodParameter): Boolean {
        return parameter.parameterType.isAssignableFrom(LoginMember::class.java)
                && parameter.hasParameterAnnotation(Login::class.java)
    }

    override fun resolveArgument(
        parameter: MethodParameter,
        mavContainer: ModelAndViewContainer?,
        webRequest: NativeWebRequest,
        binderFactory: WebDataBinderFactory?
    ): LoginMember? {
        val loginMember = webRequest.getAttribute(LoginMember.ATTR_NAME, RequestAttributes.SCOPE_REQUEST) as LoginMember?
        handleRequired(parameter, loginMember)
        return loginMember
    }

    private fun handleRequired(
        parameter: MethodParameter,
        loginMember: LoginMember?
    ) {
        val required = parameter.getParameterAnnotation(Login::class.java)?.required ?: true
        if (loginMember == null && required) {
            throw AuthException("login is required")
        }
    }

}
