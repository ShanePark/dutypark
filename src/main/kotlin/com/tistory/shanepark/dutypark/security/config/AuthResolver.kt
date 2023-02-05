package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.springframework.core.MethodParameter
import org.springframework.web.bind.support.WebDataBinderFactory
import org.springframework.web.context.request.NativeWebRequest
import org.springframework.web.context.request.RequestAttributes
import org.springframework.web.method.support.HandlerMethodArgumentResolver
import org.springframework.web.method.support.ModelAndViewContainer

class AuthResolver : HandlerMethodArgumentResolver {
    override fun supportsParameter(parameter: MethodParameter): Boolean {
        return parameter.parameterType == LoginMember::class.java
    }

    override fun resolveArgument(
        parameter: MethodParameter,
        mavContainer: ModelAndViewContainer?,
        webRequest: NativeWebRequest,
        binderFactory: WebDataBinderFactory?
    ): LoginMember? {
        val required = parameter.getParameterAnnotation(Login::class.java)?.let {
            it.required
        } ?: true

        webRequest.getNativeRequest(HttpServletRequest::class.java)?.let {
            it.cookies?.forEach { cookie ->
                if (cookie.name == "SESSION") {
                    return webRequest.getAttribute("loginMember", RequestAttributes.SCOPE_REQUEST) as LoginMember
                }
            }
        }
        if (required)
            throw AuthenticationException("login is required")
        return null
    }
}
