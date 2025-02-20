package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime
import java.time.YearMonth
import java.util.*

class ScheduleServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `Create schedule success test`() {
        // given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            description = "description1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        // When
        val loginMember = loginMember(member)
        val createSchedule1 = scheduleService.createSchedule(loginMember, scheduleUpdateDto1)
        val createSchedule2 = scheduleService.createSchedule(loginMember, scheduleUpdateDto2)
        val createSchedule3 = scheduleService.createSchedule(loginMember, scheduleUpdateDto3)

        // Then
        assertThat(createSchedule1).isNotNull
        val id = createSchedule1.id
        assertThat(id).isNotNull
        val findSchedule = scheduleRepository.findById(id).orElseThrow()
        assertThat(findSchedule).isNotNull
        assertThat(findSchedule.content).isEqualTo(scheduleUpdateDto1.content)
        assertThat(findSchedule.description).isEqualTo(scheduleUpdateDto1.description)
        assertThat(findSchedule.startDateTime).isEqualTo(scheduleUpdateDto1.startDateTime)
        assertThat(findSchedule.endDateTime).isEqualTo(scheduleUpdateDto1.endDateTime)
        assertThat(findSchedule.position).isEqualTo(0)

        assertThat(createSchedule2).isNotNull
        assertThat(createSchedule2.position).isEqualTo(0)
        assertThat(createSchedule3.position).isEqualTo(1)
    }

    @Test
    fun `can't create other member's schedule`() {
        // given
        val member = TestData.member
        val otherMember = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = otherMember.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        // When
        val loginMember = loginMember(member)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        }
    }

    @Test
    fun `update Schedule Test`() {
        // given
        val member = TestData.member
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            description = "description1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            description = "description2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val loginMember = loginMember(member)
        val updatedSchedule = scheduleService.updateSchedule(loginMember, schedule.id, scheduleUpdateDto)

        // Then
        assertThat(updatedSchedule).isNotNull
        assertThat(updatedSchedule.content).isEqualTo(scheduleUpdateDto.content)
        assertThat(updatedSchedule.description).isEqualTo(scheduleUpdateDto.description)
        assertThat(updatedSchedule.startDateTime).isEqualTo(scheduleUpdateDto.startDateTime)
        assertThat(updatedSchedule.endDateTime).isEqualTo(scheduleUpdateDto.endDateTime)
        assertThat(updatedSchedule.position).isEqualTo(0)
    }

    @Test
    fun `can't update other member's schedule`() {
        // given
        val member = TestData.member
        val otherMember = TestData.member2
        val schedule = Schedule(
            member = otherMember,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val loginMember = loginMember(member)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.updateSchedule(loginMember, schedule.id, scheduleUpdateDto)
        }
    }

    @Test
    fun `delete schedule test`() {
        // given
        val member = TestData.member
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        val loginMember = loginMember(member)
        scheduleService.deleteSchedule(loginMember, schedule.id)

        em.clear()

        // Then
        val findSchedule = scheduleRepository.findById(schedule.id)
        assertThat(findSchedule).isEmpty
    }

    @Test
    fun `can't delete other member's schedule`() {
        // given
        val member = TestData.member
        val otherMember = TestData.member2
        val schedule = Schedule(
            member = otherMember,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        val loginMember = loginMember(member)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.deleteSchedule(loginMember, schedule.id)
        }
    }

    @Test
    fun `Find Schedules`() {
        // given
        val member = TestData.member
        val schedule1 = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        val schedule2 = Schedule(
            member = member,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 12, 0, 0),
            position = 0
        )
        val schedule3 = Schedule(
            member = member,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 12, 0, 0),
            position = 1
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2, schedule3))

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val result =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member), member.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        assertThat(result).hasSize(calendarView.size)
        val paddingBefore = calendarView.paddingBefore
        assertThat(result[paddingBefore + 9 - 1]).hasSize(0)
        assertThat(result[paddingBefore + 10 - 1]).hasSize(3)
        assertThat(result[paddingBefore + 11 - 1]).hasSize(2)
        assertThat(result[paddingBefore + 12 - 1]).hasSize(2)

        val schedules = result[paddingBefore + 12 - 1]
        assertThat(schedules[0].position).isLessThan(schedules[1].position)

    }

    @Test
    fun `find schedules over month`() {
        // given
        val member = TestData.member
        val schedule1 = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 3, 30, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 5, 0, 0),
            position = 0
        )
        val schedule2 = Schedule(
            member = member,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 6, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 6, 0, 0),
            position = 0
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2))

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val result =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member), member.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        assertThat(result).hasSize(calendarView.size)
        val paddingBefore = calendarView.paddingBefore

        val lastDayOfMarch = result[paddingBefore - 1]
        assertThat(lastDayOfMarch).hasSize(1)
        assertThat(lastDayOfMarch[0].content).isEqualTo(schedule1.content)
        assertThat(lastDayOfMarch[0].dayOfMonth).isEqualTo(31)
        assertThat(lastDayOfMarch[0].daysFromStart).isEqualTo(2)

        val aprilFirst = result[paddingBefore]
        assertThat(aprilFirst).hasSize(1)
        assertThat(aprilFirst[0].content).isEqualTo(schedule1.content)
        assertThat(aprilFirst[0].dayOfMonth).isEqualTo(1)
        assertThat(aprilFirst[0].totalDays).isEqualTo(7)
        assertThat(aprilFirst[0].daysFromStart).isEqualTo(3)
        assertThat(aprilFirst[0].position).isEqualTo(0)

        assertThat(result[paddingBefore + 1 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 2 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 3 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 4 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 5 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 6 - 1]).hasSize(1)
        for (i in 7..30) {
            assertThat(result[paddingBefore + i - 1]).isEmpty()
        }

        val mayFirst = result[calendarView.paddingBefore + calendarView.lengthOfMonth]
        assertThat(mayFirst).isEmpty()
    }

    @Test
    fun `find Schedules Over year`() {
        // given
        val yearMonth = YearMonth.of(2023, 12)

        val member = TestData.member
        val schedule1 = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(yearMonth.year, yearMonth.month, 31, 0, 0),
            endDateTime = LocalDateTime.of(yearMonth.year, yearMonth.month, 31, 0, 0),
            position = 0
        )
        val schedule2 = Schedule(
            member = member,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2024, 1, 1, 0, 0),
            endDateTime = LocalDateTime.of(2024, 1, 1, 0, 0),
            position = 0
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2))

        // When
        val result =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member), member.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        assertThat(result).hasSize(calendarView.size)
        assertThat(result[calendarView.paddingBefore - 1 + 31][0].content).isEqualTo("schedule1")
        assertThat(result[calendarView.paddingBefore - 1 + 31 + 1][0].content).isEqualTo("schedule2")
    }

    @Test
    fun `update Schedule Position test`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        val loginMember = loginMember(member)
        val schedule1 = scheduleService.createSchedule(loginMember, scheduleUpdateDto1)
        val schedule2 = scheduleService.createSchedule(loginMember, scheduleUpdateDto2)
        val schedule3 = scheduleService.createSchedule(loginMember, scheduleUpdateDto3)
        assertThat(schedule1.position).isEqualTo(0)
        assertThat(schedule2.position).isEqualTo(1)
        assertThat(schedule3.position).isEqualTo(2)

        // When
        scheduleService.swapSchedulePosition(loginMember, schedule1.id, schedule2.id)
        em.flush()
        em.clear()

        // Then
        val findSchedule1 = scheduleRepository.findById(schedule1.id)
        val findSchedule2 = scheduleRepository.findById(schedule2.id)
        val findSchedule3 = scheduleRepository.findById(schedule3.id)
        assertThat(findSchedule2.get().position).isEqualTo(0)
        assertThat(findSchedule1.get().position).isEqualTo(1)
        assertThat(findSchedule3.get().position).isEqualTo(2)
    }

    @Test
    fun `Different start date can't update schedule position`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        val loginMember = loginMember(member)
        val schedule1 = scheduleService.createSchedule(loginMember, scheduleUpdateDto1)
        val schedule2 = scheduleService.createSchedule(loginMember, scheduleUpdateDto2)
        val schedule3 = scheduleService.createSchedule(loginMember, scheduleUpdateDto3)

        scheduleService.swapSchedulePosition(loginMember, schedule1.id, schedule2.id)
        // Then
        assertThrows<IllegalArgumentException> {
            scheduleService.swapSchedulePosition(loginMember, schedule2.id, schedule3.id)
        }
    }

    @Test
    fun `can't change schedule position if not owner or department manager`() {
        // Given
        val member = TestData.member
        val otherMember = TestData.member2
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = otherMember.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        val loginMember = loginMember(member)
        val schedule1 = scheduleService.createSchedule(loginMember, scheduleUpdateDto1)
        val schedule2 = scheduleService.createSchedule(loginMember(otherMember), scheduleUpdateDto2)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.swapSchedulePosition(loginMember, schedule1.id, schedule2.id)
        }
    }

    @Test
    fun `tag friend test`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(member)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(member, friend)

        // When
        scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)

        // Then
        val findSchedule = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(findSchedule.tags).hasSize(1)
        assertThat(findSchedule.tags[0].member.id).isEqualTo(friend.id)
    }

    @Test
    fun `can't tag a person to schedule if not friend`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        // When
        val loginMember = loginMember(member)
        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)


        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)
        }
    }

    @Test
    fun `can't tag a friend who is already tagged`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(member)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(member, friend)
        scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)

        // When
        // Then
        assertThrows<IllegalArgumentException> {
            scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)
        }

    }

    @Test
    fun `untag friend test`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(member)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(member, friend)
        scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)

        // When
        scheduleService.untagFriend(loginMember, schedule.id, friend.id!!)

        // Then
        val findSchedule = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(findSchedule.tags).isEmpty()
    }

    @Test
    fun `untag self test`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(member)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(member, friend)

        scheduleService.tagFriend(loginMember, schedule.id, friend.id!!)
        assertThat(scheduleRepository.findById(schedule.id).orElseThrow().tags).hasSize(1)


        // When
        val friendLoginMember = loginMember(friend)
        scheduleService.untagSelf(friendLoginMember, schedule.id)

        // Then
        val findSchedule = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(findSchedule.tags).isEmpty()
    }

    @Test
    fun `can't untag self if not tagged`() {
        // Given
        val member = TestData.member
        val friend = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(member)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(member, friend)

        // When
        val friendLoginMember = loginMember(friend)

        // Then
        assertThrows<IllegalArgumentException> {
            scheduleService.untagSelf(friendLoginMember, schedule.id)
        }
    }

    @Test
    fun `find schedules include tagged schedules`() {
        // Given
        val owner = TestData.member
        val taggedPerson = TestData.member2
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = owner.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val loginMember = loginMember(owner)

        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        makeThemFriend(owner, taggedPerson)

        scheduleService.tagFriend(loginMember, schedule.id, taggedPerson.id!!)

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val taggedPersonSchedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(owner), taggedPerson.id!!, yearMonth)
        val ownerSchedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(owner), owner.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        val paddingBefore = calendarView.paddingBefore

        val scheduleForOwner = ownerSchedules[paddingBefore + 10 - 1]
        assertThat(scheduleForOwner).hasSize(1)
        assertThat(scheduleForOwner[0].isTagged).isFalse

        val scheduleForTaggedPerson = taggedPersonSchedules[paddingBefore + 10 - 1]
        assertThat(scheduleForTaggedPerson).hasSize(1)
        assertThat(scheduleForTaggedPerson[0].isTagged).isTrue

        assertThat(scheduleForTaggedPerson[0].id).isEqualTo(schedule.id)
    }

    @Test
    fun `schedules include tags`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        val updateDto1 = ScheduleUpdateDto(
            memberId = member1.id!!,
            content = "member1Schedule",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val updateDto2 = ScheduleUpdateDto(
            memberId = member2.id!!,
            content = "member2Schedule",
            startDateTime = LocalDateTime.of(2023, 4, 10, 1, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 1, 0),
        )

        val loginMember = loginMember(member1)
        val loginMember2 = loginMember(member2)

        val member1Schedule = scheduleService.createSchedule(loginMember, updateDto1)
        val member2Schedule = scheduleService.createSchedule(loginMember2, updateDto2)
        makeThemFriend(member1, member2)

        scheduleService.tagFriend(loginMember, member1Schedule.id, member2.id!!)
        scheduleService.tagFriend(loginMember2, member2Schedule.id, member1.id!!)

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val ownerSchedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member1), member1.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)

        val scheduleForOwner = ownerSchedules[calendarView.paddingBefore + 10 - 1]
        assertThat(scheduleForOwner).hasSize(2)

        val member1ScheduleDto = scheduleForOwner[0]
        assertThat(member1ScheduleDto.isTagged).isFalse
        assertThat(member1ScheduleDto.tags).hasSize(1)
        assertThat(member1ScheduleDto.tags[0].id).isEqualTo(member2.id)

        val member2ScheduleDto = scheduleForOwner[1]
        assertThat(member2ScheduleDto.isTagged).isTrue()
        assertThat(member2ScheduleDto.tags).hasSize(1)
        assertThat(member2ScheduleDto.tags[0].id).isEqualTo(member1.id)
    }

    @Test
    fun `Tagged schedules always comes after their own schedules`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2

        val loginMember = loginMember(member1)
        val loginMember2 = loginMember(member2)

        val dayOfMonth = 10
        val own1 = scheduleService.createSchedule(
            loginMember, ScheduleUpdateDto(
                memberId = member1.id!!,
                content = "own1Schedule",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 0, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 0, 0),
            )
        )
        val tagged = scheduleService.createSchedule(
            loginMember2, ScheduleUpdateDto(
                memberId = member2.id!!,
                content = "member2Schedule",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
            )
        )
        val own2 = scheduleService.createSchedule(
            loginMember, ScheduleUpdateDto(
                memberId = member1.id!!,
                content = "own2Schedule",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 2, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 2, 0),
            )
        )
        makeThemFriend(member1, member2)

        scheduleService.tagFriend(loginMember2, tagged.id, member1.id!!)

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val ownerSchedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member1), member1.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)

        val scheduleForOwner = ownerSchedules[calendarView.paddingBefore + dayOfMonth - 1]
        assertThat(scheduleForOwner).hasSize(3)
        val own1Index = findIndex(scheduleForOwner, own1.id)
        val own2Index = findIndex(scheduleForOwner, own2.id)
        val taggedIndex = findIndex(scheduleForOwner, tagged.id)
        assertThat(own1Index).isLessThan(taggedIndex)
        assertThat(own2Index).isLessThan(taggedIndex)
    }

    private fun findIndex(schedules: List<ScheduleDto>, id: UUID): Int {
        for (i in schedules.indices) {
            if (schedules[i].id == id) {
                return i
            }
        }
        return -1
    }

    @Test
    fun `tagged schedule is visible even if it is only for family`() {
        // Given
        // member2 creates a schedule and then tags member1
        val member1 = TestData.member
        val member2 = TestData.member2
        val loginMember2 = loginMember(member2)

        val dayOfMonth = 10
        val tagged = scheduleService.createSchedule(
            loginMember2, ScheduleUpdateDto(
                memberId = member2.id!!,
                content = "member2Schedule",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                visibility = Visibility.FAMILY
            )
        )
        makeThemFriend(member1, member2)

        // When
        scheduleService.tagFriend(loginMember2, tagged.id, member1.id!!)
        val yearMonth = YearMonth.of(2023, 4)
        val ownerSchedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember = loginMember(member1), member1.id!!, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        val schedules = ownerSchedules[calendarView.paddingBefore + dayOfMonth - 1]
        assertThat(schedules).isNotEmpty
    }

    @Test
    fun `can not retrieve FAMILY only schedules even if they are friend`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        val loginMember2 = loginMember(member2)

        val dayOfMonth = 10
        scheduleService.createSchedule(
            loginMember2, ScheduleUpdateDto(
                memberId = member2.id!!,
                content = "member2Schedule",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                visibility = Visibility.FAMILY
            )
        )
        scheduleService.createSchedule(
            loginMember2, ScheduleUpdateDto(
                memberId = member2.id!!,
                content = "member2Schedule2",
                startDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                endDateTime = LocalDateTime.of(2023, 4, dayOfMonth, 1, 0),
                visibility = Visibility.FRIENDS
            )
        )
        makeThemFriend(member1, member2)

        // When
        val yearMonth = YearMonth.of(2023, 4)

        // Then
        val schedules =
            scheduleService.findSchedulesByYearAndMonth(loginMember(member1), member2.id!!, yearMonth)
        val calendarView = CalendarView(yearMonth)
        val scheduleOfDay = schedules[calendarView.paddingBefore + dayOfMonth - 1]
        assertThat(scheduleOfDay).hasSize(1)
    }

    @Test
    fun `if not friend and calendar visibility is only for friends, can not get schedules even if they are in same department`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.FRIENDS)
        val login = TestData.member2

        target.department = TestData.department
        login.department = TestData.department

        memberRepository.save(target)
        memberRepository.save(login)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.findSchedulesByYearAndMonth(loginMember(login), target.id!!, YearMonth.of(2023, 4))
        }
    }

    @Test
    fun `if friend and calendar is only open for friends can get schedules`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.FRIENDS)
        val login = TestData.member2

        val member2 = TestData.member2
        makeThemFriend(target, member2)

        // When
        val result = scheduleService.findSchedulesByYearAndMonth(loginMember(login), target.id!!, YearMonth.of(2023, 4))

        // Then
        assertThat(result).isNotEmpty
    }

    @Test
    fun `if calendar visibility is private, even they are friend, can't get schedules`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PRIVATE)
        val login = TestData.member2
        makeThemFriend(target, login)

        // Then
        assertThrows<DutyparkAuthException> {
            scheduleService.findSchedulesByYearAndMonth(loginMember(login), target.id!!, YearMonth.of(2023, 4))
        }
    }

    @Test
    fun `if calendar visibility is public, even guest can get schedules`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PUBLIC)

        // When
        val result = scheduleService.findSchedulesByYearAndMonth(null, target.id!!, YearMonth.of(2023, 4))

        // Then
        assertThat(result).isNotEmpty
    }

    @Test
    fun `create schedule with private visibility`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PRIVATE
        )

        // When
        val loginMember = loginMember(member)
        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)

        // Then
        assertThat(schedule.visibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `create schedule with public visibility`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PUBLIC
        )

        // When
        val loginMember = loginMember(member)
        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)

        // Then
        assertThat(schedule.visibility).isEqualTo(Visibility.PUBLIC)
    }

    @Test
    fun `update schedule's visibility`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PRIVATE
        )

        val loginMember = loginMember(member)
        val schedule = scheduleService.createSchedule(loginMember, scheduleUpdateDto)
        assertThat(schedule.visibility).isEqualTo(Visibility.PRIVATE)

        // When
        val updatedSchedule = scheduleService.updateSchedule(
            loginMember,
            schedule.id,
            scheduleUpdateDto.copy(visibility = Visibility.PUBLIC)
        )

        // Then
        assertThat(updatedSchedule.visibility).isEqualTo(Visibility.PUBLIC)
    }

    @Test
    fun `guest can't see private and friends level schedules`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PUBLIC)

        val dateTime = LocalDateTime.of(2024, 3, 9, 0, 0)
        val private = makeSchedule(target, Visibility.PRIVATE, dateTime)
        val friends = makeSchedule(target, Visibility.FRIENDS, dateTime)
        val public = makeSchedule(target, Visibility.PUBLIC, dateTime)

        // When
        val result = scheduleService.findSchedulesByYearAndMonth(null, target.id!!, YearMonth.of(2024, 3))

        // Then
        val calendarView = CalendarView(YearMonth.of(2024, 3))
        val index = calendarView.getIndex(target = dateTime.toLocalDate())
        val schedulesIds = result[index].map { it.id }.toList()
        assertThat(schedulesIds).contains(public.id)
        assertThat(schedulesIds).doesNotContain(friends.id)
        assertThat(schedulesIds).doesNotContain(private.id)
    }

    @Test
    fun `friend can retrieve schedules for friends`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.FRIENDS)

        val dateTime = LocalDateTime.of(2024, 3, 9, 0, 0)
        val private = makeSchedule(target, Visibility.PRIVATE, dateTime)
        val friends = makeSchedule(target, Visibility.FRIENDS, dateTime)
        val public = makeSchedule(target, Visibility.PUBLIC, dateTime)

        val friend = TestData.member2
        makeThemFriend(target, friend)

        // When
        val result =
            scheduleService.findSchedulesByYearAndMonth(loginMember(friend), target.id!!, YearMonth.of(2024, 3))

        // Then
        val calendarView = CalendarView(YearMonth.of(2024, 3))
        val index = calendarView.getIndex(target = dateTime.toLocalDate())
        val schedulesIds = result[index].map { it.id }.toList()
        assertThat(schedulesIds).contains(public.id)
        assertThat(schedulesIds).contains(friends.id)
        assertThat(schedulesIds).doesNotContain(private.id)
    }

    @Test
    fun `user can retrieve self private schedules`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PRIVATE)

        val dateTime = LocalDateTime.of(2024, 3, 9, 0, 0)
        val private = makeSchedule(target, Visibility.PRIVATE, dateTime)
        val friends = makeSchedule(target, Visibility.FRIENDS, dateTime)
        val public = makeSchedule(target, Visibility.PUBLIC, dateTime)

        // When
        val result =
            scheduleService.findSchedulesByYearAndMonth(loginMember(target), target.id!!, YearMonth.of(2024, 3))

        // Then
        val calendarView = CalendarView(YearMonth.of(2024, 3))
        val index = calendarView.getIndex(target = dateTime.toLocalDate())
        val schedulesIds = result[index].map { it.id }.toList()
        assertThat(schedulesIds).contains(public.id)
        assertThat(schedulesIds).contains(friends.id)
        assertThat(schedulesIds).contains(private.id)
    }

    @Test
    fun `can not retrieve other's friends-level-tagged schedules if not logged in but friends can`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PUBLIC)
        val friend = TestData.member2
        makeThemFriend(target, friend)

        val dateTime = LocalDateTime.of(2024, 3, 9, 0, 0)
        val friendsSchedule = makeSchedule(friend, Visibility.FRIENDS, dateTime)

        scheduleService.tagFriend(loginMember(friend), friendsSchedule.id, target.id!!)

        // When
        val notLoginResult = scheduleService.findSchedulesByYearAndMonth(null, target.id!!, YearMonth.of(2024, 3))
        val friendResult =
            scheduleService.findSchedulesByYearAndMonth(loginMember(friend), target.id!!, YearMonth.of(2024, 3))

        // Then
        val calendarView = CalendarView(YearMonth.of(2024, 3))
        val index = calendarView.getIndex(target = dateTime.toLocalDate())

        assertThat(notLoginResult[index].map { it.id }.toList()).doesNotContain(friendsSchedule.id)
        assertThat(friendResult[index].map { it.id }.toList()).contains(friendsSchedule.id)
    }

    @Test
    fun `can retrieve other's tagged public schedule even if not logged in`() {
        // Given
        val target = TestData.member
        updateVisibility(target, Visibility.PUBLIC)
        val friend = TestData.member2
        makeThemFriend(target, friend)

        val dateTime = LocalDateTime.of(2024, 3, 9, 0, 0)
        val publicSchedule = makeSchedule(friend, Visibility.PUBLIC, dateTime)

        scheduleService.tagFriend(loginMember(friend), publicSchedule.id, target.id!!)

        // When
        val notLoginResult = scheduleService.findSchedulesByYearAndMonth(null, target.id!!, YearMonth.of(2024, 3))

        // Then
        val calendarView = CalendarView(YearMonth.of(2024, 3))
        val index = calendarView.getIndex(target = dateTime.toLocalDate())

        assertThat(notLoginResult[index].map { it.id }.toList()).contains(publicSchedule.id)
    }

    private fun makeSchedule(target: Member, visibility: Visibility, dateTime: LocalDateTime): Schedule {
        return scheduleService.createSchedule(
            loginMember(target), ScheduleUpdateDto(
                memberId = target.id!!,
                content = "private",
                startDateTime = dateTime,
                endDateTime = dateTime,
                visibility = visibility,
            )
        )
    }

}
