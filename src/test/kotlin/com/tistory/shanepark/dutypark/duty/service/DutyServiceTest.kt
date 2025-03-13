package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.service.FriendService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.YearMonth

internal class DutyServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var friendService: FriendService

    @Test
    @DisplayName("create new duty")
    fun create() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = dutyTypes[0].id,
                memberId = member.id!!,
            )
        )

        val dutyDto = dutyService.getDutiesAsMap(member, 2022, 10)[10]
        assertThat(dutyDto).isNotNull
        dutyDto?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }

    }

    @Test
    @DisplayName("change original duty to new duty")
    fun update() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = dutyTypes[1].id,
                memberId = member.id!!,
            )
        )

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[1].name)
        }

    }

    @Test
    @DisplayName("delete original duty")
    fun delete() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = null,
                memberId = member.id!!,
            )
        )
        assertThat(dutyService.getDutiesAsMap(member, 2022, 10)[10]).isNull()
    }

    @Test
    @DisplayName("wrong member Id")
    fun wrongMemberId() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        assertThrows<NoSuchElementException> {
            dutyService.update(
                DutyUpdateDto(
                    year = 2022,
                    month = 10,
                    day = 10,
                    dutyTypeId = null,
                    memberId = -1L,
                )
            )
        }

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

    @Test
    @DisplayName("wrong duty Type Id")
    fun wrongDutyTypeId() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        assertThrows<NoSuchElementException> {
            dutyService.update(
                DutyUpdateDto(
                    year = 2022,
                    month = 10,
                    day = 10,
                    dutyTypeId = -1,
                    memberId = member.id!!,
                )
            )
        }

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

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
        val duties = dutyService.getDuties(member.id!!, YearMonth.of(2023, 4), loginMember(member))

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
        assertThrows<DutyparkAuthException> {
            dutyService.getDuties(member.id!!, YearMonth.of(2023, 4), loginMember(member2))
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
        val duties = dutyService.getDuties(target.id!!, YearMonth.of(2023, 4), loginMember(login))

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
        assertThrows<DutyparkAuthException> {
            dutyService.getDuties(target.id!!, YearMonth.of(2023, 4), loginMember(login))
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
        dutyService.getDuties(target.id!!, YearMonth.of(2023, 4), loginMember(login))
    }

    @Test
    fun `duty batch update set all duties`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes

        // When
        dutyService.update(
            DutyBatchUpdateDto(
                year = 2025,
                month = 1,
                dutyTypeId = dutyTypes[1].id,
                memberId = member.id!!
            )
        )

        // Then
        val duties = dutyService.getDutiesAsMap(member, 2025, 1)
        assertThat(duties).hasSize(31)
        assertThat(duties.filter { it.value?.dutyType == dutyTypes[1].name }).hasSize(31)
    }

    @Test
    fun `duty batch update delete all duties if dutyTypeId is null`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2025,
                dutyMonth = 1,
                dutyDay = 1,
                dutyType = dutyTypes[0],
                member = member
            )
        )

        // When
        dutyService.update(
            DutyBatchUpdateDto(
                year = 2025,
                month = 1,
                dutyTypeId = null,
                memberId = member.id!!
            )
        )

        // Then
        val duties = dutyService.getDutiesAsMap(member, 2025, 1)
        assertThat(duties).isEmpty()
    }

    @Test
    fun `duty batch update dutyTypeId if already exists`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2025,
                dutyMonth = 1,
                dutyDay = 1,
                dutyType = dutyTypes[0],
                member = member
            )
        )

        // When
        dutyService.update(
            DutyBatchUpdateDto(
                year = 2025,
                month = 1,
                dutyTypeId = dutyTypes[1].id,
                memberId = member.id!!
            )
        )

        // Then
        val duties = dutyService.getDutiesAsMap(member, 2025, 1)
        assertThat(duties).hasSize(31)
        assertThat(duties.filter { it.value?.dutyType == dutyTypes[1].name }).hasSize(31)
    }

}
