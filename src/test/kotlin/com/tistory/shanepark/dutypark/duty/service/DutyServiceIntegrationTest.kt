package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.service.FriendService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDate
import java.time.YearMonth

internal class DutyServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var friendService: FriendService

    @Test
    fun `test getDuties`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 3,
                dutyDay = 31,
                dutyType = dutyTypes[0],
                member = member
            )
        )
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 4,
                dutyDay = 10,
                dutyType = dutyTypes[0],
                member = member
            )
        )

        // When
        val duties = dutyService.getDuties(member.id!!, 2023, 4, loginMember(member))

        // Then
        assertThat(duties).hasSize(42)
        assertThat(duties[0].month).isEqualTo(3)
        assertThat(duties[0].day).isEqualTo(26)
        assertThat(duties[5].dutyType).isEqualTo(dutyTypes[0].name)
        assertThat(duties[6].day).isEqualTo(1)
        val dutyDto = duties[15]
        assertThat(dutyDto.day).isEqualTo(10)
        assertThat(dutyDto.dutyType).isEqualTo(dutyTypes[0].name)
        duties[41].let {
            assertThat(it.month).isEqualTo(5)
            assertThat(it.day).isEqualTo(6)
        }
    }

    @Test
    fun `if not friend and calendar is only open for friends and they are not in same team, then can't get duty`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 3,
                dutyDay = 31,
                dutyType = dutyTypes[0],
                member = member
            )
        )
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 4,
                dutyDay = 10,
                dutyType = dutyTypes[0],
                member = member
            )
        )

        val member2 = TestData.member2

        // When
        member.team = TestData.team
        member2.team = TestData.team2
        memberRepository.save(member)
        memberRepository.save(member2)

        // Then
        assertThrows<AuthException> {
            dutyService.getDuties(member.id!!, 2023, 4, loginMember(member2))
        }
    }

    @Test
    fun `if friend and calendar is only open for friends can get duty`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.FRIENDS)
        val login = TestData.member2

        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 3,
                dutyDay = 31,
                dutyType = dutyTypes[0],
                member = target
            )
        )
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 4,
                dutyDay = 10,
                dutyType = dutyTypes[0],
                member = target
            )
        )

        friendService.sendFriendRequest(loginMember(login), target.id!!)
        friendService.acceptFriendRequest(loginMember(target), login.id!!)

        // When
        val duties = dutyService.getDuties(target.id!!, 2023, 4, loginMember(login))

        // Then
        assertThat(duties).hasSize(42)
    }

    @Test
    fun `if not my calendar and the member's calendar visibility is private can't get duty`() {
        // Given
        val target = TestData.member
        target.team = TestData.team2
        val login = TestData.member2
        login.team = TestData.team

        memberRepository.save(target)
        memberRepository.save(login)
        // When
        updateVisibility(target, Visibility.PRIVATE)

        // Then
        assertThrows<AuthException> {
            dutyService.getDuties(target.id!!, 2023, 4, loginMember(login))
        }
    }

    @Test
    fun `even if calendar visibility is private, if they are on the same group they can see each other's duty`() {
        // Given
        val target = TestData.member
        target.team = TestData.team
        val login = TestData.member2
        login.team = TestData.team

        memberRepository.save(target)
        memberRepository.save(login)
        // When
        updateVisibility(target, Visibility.PRIVATE)

        // Then does not throw exception
        dutyService.getDuties(target.id!!, 2023, 4, loginMember(login))
    }

    @Test
    fun `batch update replaces existing monthly overrides without unique constraint collisions`() {
        val member = TestData.member
        val month = YearMonth.of(2026, 8)
        val oldType = TestData.dutyTypes[0]
        val newType = TestData.dutyTypes[1]
        dutyRepository.saveAndFlush(Duty(month.atDay(1), oldType, member))

        dutyService.update(
            DutyBatchUpdateDto(
                year = month.year,
                month = month.monthValue,
                dutyTypeId = newType.id,
                memberId = member.id!!,
            )
        )
        dutyRepository.flush()

        val replaced = dutyRepository.findAllByMemberAndDutyDateBetween(
            member,
            month.atDay(1),
            month.atEndOfMonth(),
        )
        assertThat(replaced).hasSize(month.lengthOfMonth())
        assertThat(replaced.map { it.dutyDate }).doesNotHaveDuplicates()
        assertThat(replaced).allMatch { it.dutyType?.id == newType.id }
    }

}
