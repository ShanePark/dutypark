package com.tistory.shanepark.dutypark.security.config

import io.jsonwebtoken.security.Keys
import org.junit.jupiter.api.Test
import java.util.*

class HS256Base64KeyGenerate {

    @Test
    fun test() {
        val key = Keys.secretKeyFor(io.jsonwebtoken.SignatureAlgorithm.HS256)
            .encoded

        Base64.getEncoder().encode(key).let {
            println(String(it))
        }
    }


}

