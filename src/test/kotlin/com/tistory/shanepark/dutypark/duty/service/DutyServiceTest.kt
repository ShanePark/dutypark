package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.Mockito.reset
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.kotlin.any
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.mock.mockito.SpyBean
import java.time.LocalDate
import java.util.UUID

internal class DutyServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var holidayRepository: HolidayRepository

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var friendService: FriendService

    @SpyBean
    lateinit var holidayServiceSpy: HolidayService

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

        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2022, 10, loginMember(member))
        val dutyDto = duties.filter { it.day == 10 }[0]

        assertThat(dutyDto).isNotNull
        assert(dutyDto.dutyType == dutyTypes[0].name)

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

        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2022, 10, loginMember(member))
        val dutyDto = duties.filter { it.day == 10 }[0]
        assert(dutyDto.dutyType == dutyTypes[1].name)

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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2022, 10, loginMember(member))
        val dutyDto = duties.filter { it.day == 10 }[0]
        assertThat(dutyDto.dutyType).isNull()
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

        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2022, 10, loginMember(member))
        val dutyDto = duties.filter { it.day == 10 }[0]
        assert(dutyDto.dutyType == dutyTypes[0].name)
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

        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2022, 10, loginMember(member))
        val dutyDto = duties.filter { it.day == 10 }[0]
        assert(dutyDto.dutyType == dutyTypes[0].name)
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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2023, 4, loginMember(member))

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
            dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2023, 4, loginMember(member2))
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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(target.id!!, 2023, 4, loginMember(login))

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
            dutyService.getDutiesAndInitLazyIfNeeded(target.id!!, 2023, 4, loginMember(login))
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
        dutyService.getDutiesAndInitLazyIfNeeded(target.id!!, 2023, 4, loginMember(login))
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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2025, 1, loginMember(member))
        assertThat(duties.filter { it.dutyType == dutyTypes[1].name }).hasSize(31)
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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2025, 1, loginMember(member))
        assertThat(duties.filter { !it.isOff }).isEmpty()
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
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2025, 1, loginMember(member))
        assertThat(duties.filter { it.dutyType == dutyTypes[1].name }).hasSize(31)
    }

    @Test
    fun `init weekdays duties if workType is weekday`() {
        // Given
        val member = TestData.member
        val team = member.team ?: throw NoSuchElementException("Team not found for member")
        team.workType = WorkType.WEEKDAY
        val dutyName = "근무"
        team.addDutyType(dutyName = dutyName, dutyColor = "#f0f8ff")
        teamRepository.save(team)

        // Populate holidays for the entire year to prevent external API calls
        val holidays2024 = generateSequence(LocalDate.of(2024, 1, 1)) { it.plusDays(1) }
            .takeWhile { it.year == 2024 }
            .filter { it.dayOfWeek.value <= 5 }
            .map { Holiday("weekday", false, it) }
            .toList()
        val holidays2025 = generateSequence(LocalDate.of(2025, 1, 1)) { it.plusDays(1) }
            .takeWhile { it.year == 2025 }
            .filter { it.dayOfWeek.value <= 5 }
            .map { Holiday("weekday", false, it) }
            .toList()

        val actualHolidays = listOf(
            Holiday("신정", true, LocalDate.of(2025, 1, 1)),
            Holiday("임시공휴일", true, LocalDate.of(2025, 1, 27)),
            Holiday("설날", true, LocalDate.of(2025, 1, 28)),
            Holiday("설날", true, LocalDate.of(2025, 1, 29)),
            Holiday("설날", true, LocalDate.of(2025, 1, 30))
        )
        holidayRepository.saveAll(holidays2024 + holidays2025 + actualHolidays)

        // When
        val duties = dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2025, 1, loginMember(member))

        // Then
        assertThat(duties.filter { it.dutyType == dutyName }).hasSize(20)
        for (duty in duties) {
            val date = LocalDate.of(duty.year, duty.month, duty.day)
            if (date.dayOfWeek.value > 5 || actualHolidays.any { it.localDate == date }) {
                assertThat(duty.dutyType).isNull()
                continue
            }
            assertThat(duty.dutyType).isEqualTo(dutyName)
        }
    }

    @Test
    fun `lazy init requests holiday data only once per calendar view`() {
        // Given
        val member = TestData.member
        val weekdayTeam =
            teamRepository.save(Team("weekday-team-${UUID.randomUUID()}").apply { workType = WorkType.WEEKDAY })
        weekdayTeam.addDutyType(dutyName = "근무", dutyColor = "#123456")
        weekdayTeam.addMember(member)
        memberRepository.save(member)
        teamRepository.save(weekdayTeam)

        holidayRepository.saveAll(
            listOf(
                Holiday("dummy1", false, LocalDate.of(2024, 12, 31)),
                Holiday("dummy2", false, LocalDate.of(2025, 1, 1))
            )
        )
        reset(holidayServiceSpy)

        // When
        dutyService.getDutiesAndInitLazyIfNeeded(member.id!!, 2025, 1, loginMember(member))

        // Then
        verify(holidayServiceSpy, times(1)).findHolidays(any())
    }

}
