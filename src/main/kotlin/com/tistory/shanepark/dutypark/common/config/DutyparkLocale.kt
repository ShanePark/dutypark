package com.tistory.shanepark.dutypark.common.config

import java.util.Locale

object DutyparkLocale {
    const val KOREAN = "ko"
    const val ENGLISH = "en"
    const val JAPANESE = "ja"
    const val DEFAULT = KOREAN

    val SUPPORTED_LANGUAGE_TAGS: Set<String> = setOf(KOREAN, ENGLISH, JAPANESE)
    val SUPPORTED_LOCALES: List<Locale> = listOf(Locale.KOREAN, Locale.ENGLISH, Locale.JAPANESE)

    fun normalize(languageTag: String): String {
        val trimmed = languageTag.trim()
        if (trimmed.isBlank()) {
            return DEFAULT
        }
        return Locale.forLanguageTag(trimmed).language
            .ifBlank { trimmed.lowercase(Locale.ROOT) }
    }

    fun isSupported(languageTag: String): Boolean {
        return SUPPORTED_LANGUAGE_TAGS.contains(normalize(languageTag))
    }
}
