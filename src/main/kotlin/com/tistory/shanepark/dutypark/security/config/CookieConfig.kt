package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "cookie")
data class CookieConfig(
    val secure: Boolean = true,
    val sameSite: String = "Strict",
    val domain: String? = null,
) {
    init {
        require(sameSite in setOf("Strict", "Lax", "None")) {
            "cookie.same-site must be one of Strict, Lax, or None"
        }
        require(secure || sameSite != "None") {
            "cookie.secure must be true when cookie.same-site is None"
        }
        domain?.takeIf { it.isNotBlank() }?.let(::validateDomain)
    }

    private fun validateDomain(value: String) {
        require(value.none(Char::isWhitespace)) {
            "cookie.domain must be a plain DNS hostname"
        }
        val normalized = value.trim('.').lowercase()
        val labels = normalized.split('.')
        val labelPattern = Regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
        require(
            normalized.length <= 253 && labels.size >= 2 &&
                labels.all { it.length <= 63 && labelPattern.matches(it) } &&
                labels.last().any(Char::isLetter)
        ) {
            "cookie.domain must be a plain DNS hostname"
        }
    }
}
