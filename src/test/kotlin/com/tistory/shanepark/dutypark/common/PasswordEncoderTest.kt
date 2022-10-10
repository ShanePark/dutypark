package com.tistory.shanepark.dutypark.common

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

internal class PasswordEncoderTest {

    private val passwordEncoder = PasswordEncoder()

    @Test
    fun encode() {
        val encoded1 = passwordEncoder.encode("1234")
        val encoded2 = passwordEncoder.encode("1234")

        assertThat(passwordEncoder.matches("1234", encoded1)).isTrue
        assertThat(passwordEncoder.matches("1234", encoded2)).isTrue
        assertThat(passwordEncoder.matches("1230", encoded2)).isFalse
        assertThat(encoded1).isNotEqualTo(encoded2)
    }

}
