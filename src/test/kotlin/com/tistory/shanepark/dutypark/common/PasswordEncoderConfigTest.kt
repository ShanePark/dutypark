package com.tistory.shanepark.dutypark.common

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.config.logger
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.crypto.password.PasswordEncoder

internal class PasswordEncoderConfigTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var passwordEncoder: PasswordEncoder

    private val log = logger()
    val pass = "1234"

    @Test
    fun encode() {
        val encoded1 = passwordEncoder.encode(pass)
        log.info(passwordEncoder.encode(pass))

        val encoded2 = passwordEncoder.encode(pass)

        assertThat(passwordEncoder.matches(pass, encoded1)).isTrue
        assertThat(passwordEncoder.matches(pass, encoded2)).isTrue
        assertThat(passwordEncoder.matches("1230", encoded2)).isFalse
        assertThat(encoded1).isNotEqualTo(encoded2)
    }

}
