package com.tistory.shanepark.dutypark.security.oauth.apple

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

@Component
class AppleCredentialCipher(
    @param:Value("\${oauth.apple.credential-encryption-key:}") encodedKey: String,
) {
    private val key = encodedKey.takeIf(String::isNotBlank)?.let(::decodeKey)
    private val random = SecureRandom()

    fun ensureConfigured() {
        if (key == null) throw AppleOAuthException("auth.apple.configurationUnavailable", 503)
    }

    fun encrypt(value: String): String {
        ensureConfigured()
        val configuredKey = requireNotNull(key)
        val iv = ByteArray(12).also(random::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, configuredKey, GCMParameterSpec(128, iv))
        val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return "v1:${Base64.getEncoder().encodeToString(iv)}:${Base64.getEncoder().encodeToString(ciphertext)}"
    }

    fun decrypt(value: String): String {
        ensureConfigured()
        val configuredKey = requireNotNull(key)
        val parts = value.split(':')
        if (parts.size != 3 || parts[0] != "v1") {
            throw AppleOAuthException("auth.apple.credential.invalid", 500)
        }
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                configuredKey,
                GCMParameterSpec(128, Base64.getDecoder().decode(parts[1])),
            )
            String(cipher.doFinal(Base64.getDecoder().decode(parts[2])), Charsets.UTF_8)
        } catch (e: Exception) {
            throw AppleOAuthException("auth.apple.credential.invalid", 500, e)
        }
    }

    private fun decodeKey(value: String): SecretKeySpec {
        val decoded = try {
            Base64.getDecoder().decode(value)
        } catch (e: IllegalArgumentException) {
            throw IllegalStateException("APPLE_CREDENTIAL_ENCRYPTION_KEY must be valid base64", e)
        }
        check(decoded.size == 32) { "APPLE_CREDENTIAL_ENCRYPTION_KEY must decode to exactly 32 bytes" }
        return SecretKeySpec(decoded, "AES")
    }
}
