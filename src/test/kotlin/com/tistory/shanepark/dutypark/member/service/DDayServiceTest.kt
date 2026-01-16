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
import org.mockito.ArgumentCaptor
import org.mockito.Captor
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.util.*

@ExtendWith(MockitoExtension::class)
class DDayServiceTest {

    private val fixedDate = LocalDate.of(2025, 1, 15)

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var dDayRepository: DDayRepository

    @Captor
    private lateinit var dDayEventCaptor: ArgumentCaptor<DDayEvent>

    private lateinit var dDayService: DDayService

    private lateinit var member: Member
    private lateinit var member2: Member

    @BeforeEach
    fun setUp() {
        dDayService = DDayService(memberRepository, dDayRepository)
        member = memberWithId(1L)
        member2 = memberWithId(2L)
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

    @Test
    fun `createDDay stores event and returns dto`() {
        val date = fixedDate.plusDays(5)
        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.save(any<DDayEvent>())).thenAnswer { invocation ->
            val event = invocation.getArgument<DDayEvent>(0)
            ReflectionTestUtils.setField(event, "id", 100L)
            event
        }

        val dto = dDayService.createDDay(
            loginMember = loginMember(member),
            dDaySaveDto = DDaySaveDto(
                title = "Anniversary",
                date = date,
                isPrivate = false
            )
        )

        verify(dDayRepository).save(dDayEventCaptor.capture())
        val savedEvent = dDayEventCaptor.value
        assertThat(savedEvent.title).isEqualTo("Anniversary")
        assertThat(savedEvent.isPrivate).isFalse
        assertThat(savedEvent.member).isEqualTo(member)
        assertThat(dto.title).isEqualTo("Anniversary")
        assertThat(dto.isPrivate).isFalse
    }

    @Test
    fun `findDDay allows owner for private event`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Private",
            date = fixedDate.plusDays(1),
            isPrivate = true
        )
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        val result = dDayService.findDDay(loginMember(member), event.id!!)

        assertThat(result.id).isEqualTo(event.id)
        assertThat(result.isPrivate).isTrue
    }

    @Test
    fun `findDDay blocks non-owner for private event`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Private",
            date = fixedDate.plusDays(1),
            isPrivate = true
        )
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        assertThrows<AuthException> {
            dDayService.findDDay(loginMember(member2), event.id!!)
        }
    }

    @Test
    fun `findDDays returns only public events for non-owner`() {
        val publicEvent = dDayEventWithId(
            id = 1L,
            member = member,
            title = "Public",
            date = fixedDate.plusDays(2),
            isPrivate = false
        )
        val privateEvent = dDayEventWithId(
            id = 2L,
            member = member,
            title = "Private",
            date = fixedDate.plusDays(3),
            isPrivate = true
        )
        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.findAllByMemberOrderByDate(member)).thenReturn(listOf(publicEvent, privateEvent))

        val result = dDayService.findDDays(loginMember(member2), member.id!!)

        assertThat(result).hasSize(1)
        assertThat(result.first().title).isEqualTo("Public")
    }

    @Test
    fun `findDDays returns all events for owner`() {
        val publicEvent = dDayEventWithId(
            id = 1L,
            member = member,
            title = "Public",
            date = fixedDate.plusDays(2),
            isPrivate = false
        )
        val privateEvent = dDayEventWithId(
            id = 2L,
            member = member,
            title = "Private",
            date = fixedDate.plusDays(3),
            isPrivate = true
        )
        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(dDayRepository.findAllByMemberOrderByDate(member)).thenReturn(listOf(publicEvent, privateEvent))

        val result = dDayService.findDDays(loginMember(member), member.id!!)

        assertThat(result).hasSize(2)
    }

    @Test
    fun `updateDDay requires id`() {
        assertThrows<IllegalArgumentException> {
            dDayService.updateDDay(
                loginMember(member),
                DDaySaveDto(
                    id = null,
                    title = "Update",
                    date = fixedDate.plusDays(1),
                    isPrivate = false
                )
            )
        }
    }

    @Test
    fun `updateDDay updates fields for owner`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Before",
            date = fixedDate.plusDays(1),
            isPrivate = false
        )
        val newDate = fixedDate.plusDays(10)
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        val result = dDayService.updateDDay(
            loginMember(member),
            DDaySaveDto(
                id = event.id,
                title = "After",
                date = newDate,
                isPrivate = true
            )
        )

        assertThat(result.title).isEqualTo("After")
        assertThat(event.title).isEqualTo("After")
        assertThat(event.date).isEqualTo(newDate)
        assertThat(event.isPrivate).isTrue
    }

    @Test
    fun `updateDDay blocks non-owner`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Before",
            date = fixedDate.plusDays(1),
            isPrivate = false
        )
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        assertThrows<AuthException> {
            dDayService.updateDDay(
                loginMember(member2),
                DDaySaveDto(
                    id = event.id,
                    title = "After",
                    date = fixedDate.plusDays(10),
                    isPrivate = true
                )
            )
        }
    }

    @Test
    fun `deleteDDay removes event for owner`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Delete",
            date = fixedDate.plusDays(1),
            isPrivate = false
        )
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        dDayService.deleteDDay(loginMember(member), event.id!!)

        verify(dDayRepository).delete(event)
    }

    @Test
    fun `deleteDDay blocks non-owner`() {
        val event = dDayEventWithId(
            id = 10L,
            member = member,
            title = "Delete",
            date = fixedDate.plusDays(1),
            isPrivate = false
        )
        whenever(dDayRepository.findById(event.id!!)).thenReturn(Optional.of(event))

        assertThrows<AuthException> {
            dDayService.deleteDDay(loginMember(member2), event.id!!)
        }
    }
}
