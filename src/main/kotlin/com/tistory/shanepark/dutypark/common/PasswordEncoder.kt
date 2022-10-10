package com.tistory.shanepark.dutypark.common

import com.password4j.Password
import org.springframework.stereotype.Component

@Component
class PasswordEncoder {

    fun encode(raw: String): String {
        return Password.hash(raw).withBcrypt().result
    }

    fun matches(raw: String, encoded: String): Boolean {
        return Password.check(raw, encoded).withBcrypt()
    }

}

