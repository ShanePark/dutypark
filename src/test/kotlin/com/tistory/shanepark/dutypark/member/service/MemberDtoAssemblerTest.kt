package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils

class MemberDtoAssemblerTest {
    private val socialAccounts: MemberSocialAccountService = mock()
    private val assembler = MemberDtoAssembler(socialAccounts)

    @Test
    fun `batch assembly reports only nonblank passwords as configured`() {
        val members = listOf(null, "", " \t", "encoded-password-hash").mapIndexed { index, password ->
            Member(name = "Member", password = password).also {
                ReflectionTestUtils.setField(it, "id", index.toLong() + 1)
            }
        }
        whenever(socialAccounts.findProviderMapByMemberIds(setOf(1L, 2L, 3L, 4L))).thenReturn(emptyMap())
        assertThat(assembler.toDtos(members).map { it.hasPassword }).containsExactly(false, false, false, true)
    }

    @Test
    fun `single assembly does not treat an SSO member empty password as configured`() {
        val member = Member(name = "SSO member", password = "")
        ReflectionTestUtils.setField(member, "id", 2L)
        whenever(socialAccounts.findProviderMapByMemberIds(setOf(2L)))
            .thenReturn(mapOf(2L to mapOf(SsoType.KAKAO to "provider-id")))
        val dto = assembler.toDto(member)
        assertThat(dto.hasPassword).isFalse()
        assertThat(dto.kakaoId).isEqualTo("provider-id")
        assertThat(dto.email).isNull()
    }
}
