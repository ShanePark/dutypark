package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.TestUtils
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.NullAndEmptySource
import org.junit.jupiter.params.provider.ValueSource

class MemberDtoTest {
    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = [" ", "\t\n"])
    fun `null empty and blank passwords are not reported as configured`(password: String?) {
        val dto = Member(name = "Member", email = "member@example.com", password = password).toMemberDto()
        assertThat(dto.hasPassword).isFalse()
        val mapper = TestUtils.jsr310JsonMapper()
        assertThat(mapper.readTree(mapper.writeValueAsString(dto))["hasPassword"].asBoolean()).isFalse()
    }

    @Test
    fun `a nonblank password remains configured independently of email and provider links`() {
        val dto = Member(name = "Member", email = null, password = "encoded-password-hash").toMemberDto(kakaoId = "provider-id")
        assertThat(dto.hasPassword).isTrue()
        assertThat(dto.email).isNull()
        assertThat(dto.kakaoId).isEqualTo("provider-id")
    }
}
