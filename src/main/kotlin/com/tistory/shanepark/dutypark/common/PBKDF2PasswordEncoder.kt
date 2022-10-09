package com.tistory.shanepark.dutypark.common

import org.springframework.stereotype.Component
import javax.crypto.spec.PBEKeySpec

@Component
class PBKDF2PasswordEncoder {
    fun encode(raw: String): String {
        val salt = "salt"
        PBEKeySpec(raw.toCharArray(), salt.toByteArray(), 65536, 128).run {
            return javax.crypto.SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1")
                .generateSecret(this).encoded.toString()
        }
    }
}
