package com.tistory.shanepark.dutypark.common

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.slf4j.Logger
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.security.crypto.password.PasswordEncoder

internal class PasswordEncoderTest : DutyparkIntegrationTest(){

    @Autowired
    lateinit var passwordEncoder: PasswordEncoder

    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @Test
    fun encode() {
        val encoded1 = passwordEncoder.encode("1234")
        log.info(passwordEncoder.encode("1234"))

        val encoded2 = passwordEncoder.encode("1234")

        assertThat(passwordEncoder.matches("1234", encoded1)).isTrue
        assertThat(passwordEncoder.matches("1234", encoded2)).isTrue
        assertThat(passwordEncoder.matches("1230", encoded2)).isFalse
        assertThat(encoded1).isNotEqualTo(encoded2)
    }

}
