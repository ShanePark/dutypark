package com.tistory.shanepark.dutypark.member.accountdeletion.service

import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

/**
 * Generates opaque, bearer-only deletion receipts. The raw value must never be persisted or logged.
 */
object AccountDeletionReceiptToken {
    private const val TOKEN_BYTES = 32
    private const val TOKEN_LENGTH = 43
    private val TOKEN_PATTERN = Regex("^[A-Za-z0-9_-]{$TOKEN_LENGTH}$")
    private val secureRandom = SecureRandom()
    private val encoder = Base64.getUrlEncoder().withoutPadding()

    fun generate(): String {
        val bytes = ByteArray(TOKEN_BYTES)
        secureRandom.nextBytes(bytes)
        return encoder.encodeToString(bytes)
    }

    fun hash(rawToken: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(rawToken.toByteArray(StandardCharsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    fun isValid(rawToken: String): Boolean = TOKEN_PATTERN.matches(rawToken)
}
