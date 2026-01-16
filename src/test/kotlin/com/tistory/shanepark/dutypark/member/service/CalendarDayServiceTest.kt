package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.util.*

@ExtendWith(MockitoExtension::class)
class CalendarDayServiceTest {

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var dDayRepository: DDayRepository

    private lateinit var dDayService: DDayService

    @BeforeEach
    fun setUp() {
        dDayService = DDayService(memberRepository, dDayRepository)
    }

    @Test
    fun createDDay() {
        val member = memberWithId(1L)
        val login = loginMember(member)

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.save(any<DDayEvent>())).thenAnswer { invocation ->
            val event = invocation.getArgument<DDayEvent>(0)
            ReflectionTestUtils.setField(event, "id", 100L)
            event
        }

        val createDDay = dDayService.createDDay(
            loginMember = login,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )

        assertThat(createDDay.id).isNotNull
        verify(dDayRepository).save(any<DDayEvent>())
    }

    @Test
    fun `Create fail if login Member has Problem`() {
        val invalidLogin = LoginMember(id = -1, email = "", name = "", team = "team", isAdmin = false)

        whenever(memberRepository.findById(-1L)).thenReturn(Optional.empty())

        assertThrows<NoSuchElementException> {
            dDayService.createDDay(
                loginMember = invalidLogin,
                dDaySaveDto = DDaySaveDto(
                    title = "test",
                    date = LocalDate.now().plusDays(3),
                    isPrivate = false
                )
            )
        }
    }

    @Test
    fun findDDay() {
        val member = memberWithId(1L)
        val login = loginMember(member)
        val eventDate = LocalDate.now().plusDays(3)
        val dDayEvent = dDayEventWithId(100L, member, "test", eventDate, false)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(dDayEvent))

        val findDDay = dDayService.findDDay(login, 100L)

        assertThat(findDDay.id).isEqualTo(100L)
        assertThat(findDDay.daysLeft).isEqualTo(3)

        val todayEvent = dDayEventWithId(101L, member, "today", LocalDate.now(), false)
        whenever(dDayRepository.findById(101L)).thenReturn(Optional.of(todayEvent))

        val findDDayToday = dDayService.findDDay(login, 101L)
        assertThat(findDDayToday.daysLeft).isEqualTo(0)
    }

    @Test
    fun `can't find private D-day of other person`() {
        val member = memberWithId(1L)
        val member2 = memberWithId(2L)
        val loginMember2 = loginMember(member2)
        val privateDDay = dDayEventWithId(100L, member, "test", LocalDate.now().plusDays(3), true)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(privateDDay))

        assertThrows<AuthException> {
            dDayService.findDDay(loginMember2, 100L)
        }
    }

    @Test
    fun findDDays() {
        val member = memberWithId(1L)
        val login = loginMember(member)
        val event1 = dDayEventWithId(100L, member, "test1", LocalDate.now().plusDays(3), false)
        val event2 = dDayEventWithId(101L, member, "test2", LocalDate.now().plusDays(5), false)

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.findAllByMemberOrderByDate(member)).thenReturn(listOf(event1, event2))

        val findDDays = dDayService.findDDays(login, member.id!!)

        assertThat(findDDays.size).isEqualTo(2)
        assertThat(findDDays[0].id).isEqualTo(100L)
        assertThat(findDDays.map { it.id }).containsAll(listOf(100L, 101L))
    }

    @Test
    fun `find D-Day by another person, private ones are not show`() {
        val member = memberWithId(1L)
        val member2 = memberWithId(2L)
        val loginMember2 = loginMember(member2)
        val privateEvent = dDayEventWithId(100L, member, "private", LocalDate.now().plusDays(3), true)
        val publicEvent = dDayEventWithId(101L, member, "public", LocalDate.now().plusDays(5), false)

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.findAllByMemberOrderByDate(member)).thenReturn(listOf(privateEvent, publicEvent))

        val findDDays = dDayService.findDDays(loginMember2, member.id!!)

        assertThat(findDDays.size).isEqualTo(1)
        assertThat(findDDays[0].id).isEqualTo(101L)
        assertThat(findDDays.map { it.id }).doesNotContain(100L)
    }

    @Test
    fun updateDDay() {
        val member = memberWithId(1L)
        val login = loginMember(member)
        val dDayEvent = dDayEventWithId(100L, member, "test", LocalDate.now().plusDays(3), false)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(dDayEvent))

        val updateDDayDto = DDaySaveDto(
            id = 100L,
            title = "test2",
            date = LocalDate.now().plusDays(5),
            isPrivate = true
        )

        val updateDDay = dDayService.updateDDay(
            loginMember = login,
            dDaySaveDto = updateDDayDto
        )

        assertThat(updateDDay.title).isEqualTo("test2")
        assertThat(updateDDay.date).isEqualTo(LocalDate.now().plusDays(5))
        assertThat(updateDDay.isPrivate).isEqualTo(true)
    }

    @Test
    fun `Can't update other member's D-Day event`() {
        val member = memberWithId(1L)
        val member2 = memberWithId(2L)
        val loginMember2 = loginMember(member2)
        val dDayEvent = dDayEventWithId(100L, member, "test", LocalDate.now().plusDays(3), false)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(dDayEvent))

        val updateDDayDto = DDaySaveDto(
            id = 100L,
            title = "test2",
            date = LocalDate.now().plusDays(5),
            isPrivate = true
        )

        assertThrows<AuthException> {
            dDayService.updateDDay(
                loginMember = loginMember2,
                dDaySaveDto = updateDDayDto
            )
        }
    }

    @Test
    fun deleteDDay() {
        val member = memberWithId(1L)
        val login = loginMember(member)
        val dDayEvent = dDayEventWithId(100L, member, "test", LocalDate.now().plusDays(3), false)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(dDayEvent))

        dDayService.deleteDDay(login, 100L)

        verify(dDayRepository).delete(dDayEvent)
    }

    @Test
    fun `can't delete D-day event of other member`() {
        val member = memberWithId(1L)
        val member2 = memberWithId(2L)
        val loginMember2 = loginMember(member2)
        val dDayEvent = dDayEventWithId(100L, member, "test", LocalDate.now().plusDays(3), false)

        whenever(dDayRepository.findById(100L)).thenReturn(Optional.of(dDayEvent))

        assertThrows<AuthException> {
            dDayService.deleteDDay(loginMember2, 100L)
        }
    }

    private fun memberWithId(id: Long): Member {
        val member = Member(name = "test$id", password = "")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }

    private fun loginMember(member: Member): LoginMember {
        return LoginMember(id = member.id!!, email = "", name = member.name, team = "", isAdmin = false)
    }

    private fun dDayEventWithId(id: Long, member: Member, title: String, date: LocalDate, isPrivate: Boolean): DDayEvent {
        val event = DDayEvent(member = member, title = title, date = date, isPrivate = isPrivate)
        ReflectionTestUtils.setField(event, "id", id)
        return event
    }

}
