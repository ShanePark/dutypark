package com.tistory.shanepark.dutypark.team.domain.dto

import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class TeamDtoTest {

    @Test
    fun `of builds dto with defaults and sorted duty types`() {
        val team = Team("alpha")
        setId(team, 10L)
        team.defaultDutyName = "OFF"
        team.defaultDutyColor = "#ffb3ba"
        team.dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE

        val admin = Member("admin", "admin@duty.park", "pass")
        setId(admin, 100L)
        team.addMember(admin)
        team.changeAdmin(admin)

        val dutyType1 = DutyType("B", 2, team, "#000000")
        val dutyType2 = DutyType("A", 1, team, "#111111")

        val dto = TeamDto.of(team, members = listOf(admin), dutyTypes = listOf(dutyType1, dutyType2))

        assertThat(dto.id).isEqualTo(10L)
        assertThat(dto.adminId).isEqualTo(100L)
        assertThat(dto.adminName).isEqualTo("admin")
        assertThat(dto.dutyBatchTemplate?.name).isEqualTo("SUNGSIM_CAKE")
        assertThat(dto.dutyTypes.first().name).isEqualTo("OFF")
        assertThat(dto.dutyTypes.drop(1).map { it.name }).containsExactly("A", "B")
    }

    @Test
    fun `of reports no admin when the admin no longer belongs to the team`() {
        val team = Team("gamma")
        setId(team, 20L)
        val formerAdmin = Member("former", "former@duty.park", "pass")
        setId(formerAdmin, 200L)
        team.addMember(formerAdmin)
        team.changeAdmin(formerAdmin)
        team.removeMember(formerAdmin)

        val dto = TeamDto.of(team, members = emptyList(), dutyTypes = emptyList())

        assertThat(dto.adminId).isNull()
        assertThat(dto.adminName).isNull()
    }

    @Test
    fun `ofSimple uses fallback id when team id is null`() {
        val team = Team("beta")

        val dto = TeamDto.ofSimple(team)

        assertThat(dto.id).isEqualTo(-1L)
    }

    private fun setId(target: Any, id: Long) {
        val field = target::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(target, id)
    }
}
