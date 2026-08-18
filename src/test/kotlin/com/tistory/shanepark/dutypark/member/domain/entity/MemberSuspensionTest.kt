package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.Instant

class MemberSuspensionTest {

    @Test
    fun `suspend moves an active member to SUSPENDED`() {
        val member = member()

        member.suspend()

        assertThat(member.status).isEqualTo(MemberStatus.SUSPENDED)
    }

    @Test
    fun `suspend is not allowed twice`() {
        val member = member().also { it.suspend() }

        assertThrows<IllegalStateException> { member.suspend() }
    }

    @Test
    fun `suspend is not allowed for a deletion pending member`() {
        val member = member().also { it.markDeletionPending(Instant.parse("2026-08-12T00:00:00Z")) }

        assertThrows<IllegalStateException> { member.suspend() }
    }

    @Test
    fun `reinstate moves a suspended member back to ACTIVE`() {
        val member = member().also { it.suspend() }

        member.reinstate()

        assertThat(member.status).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `reinstate is not allowed when the member is not suspended`() {
        val member = member()

        assertThrows<IllegalStateException> { member.reinstate() }
    }

    @Test
    fun `deletion pending is not allowed for a suspended member`() {
        val member = member().also { it.suspend() }

        assertThrows<IllegalStateException> {
            member.markDeletionPending(Instant.parse("2026-08-12T00:00:00Z"))
        }
    }

    private fun member() = Member(name = "member", email = "member@duty.park", password = "pass")

}
