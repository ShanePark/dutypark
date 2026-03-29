package com.tistory.shanepark.dutypark.common.config

import org.springframework.context.MessageSource
import org.springframework.context.i18n.LocaleContextHolder
import org.springframework.stereotype.Component

@Component
class LocalizedMessageResolver(
    private val messageSource: MessageSource,
) {
    companion object {
        private val LEGACY_MESSAGE_CODES = mapOf(
            "authentication Exception" to "auth.unauthorized",
            "login is required" to "auth.required",
        )
    }

    fun resolve(codeOrMessage: String?, defaultCode: String? = null, vararg args: Any?): String {
        val locale = LocaleContextHolder.getLocale()
        val messageArgs: Array<Any> = args.map { it ?: "" }.toTypedArray()
        val candidate = codeOrMessage?.let { LEGACY_MESSAGE_CODES[it] ?: it }
        val fallback = when {
            candidate != null && candidate != codeOrMessage -> messageSource.getMessage(candidate, messageArgs, candidate, locale)
            codeOrMessage != null -> codeOrMessage
            defaultCode != null -> messageSource.getMessage(defaultCode, messageArgs, defaultCode, locale)
            else -> ""
        } ?: ""
        val messageCode = candidate ?: defaultCode ?: return fallback
        return messageSource.getMessage(messageCode, messageArgs, fallback, locale) ?: fallback
    }
}
