package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDate

class DDayServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dDayService: DDayService

    @Autowired
    lateinit var dDayRepository: DDayRepository

    @Test
    fun `createDDay stores event and returns dto`() {
        val dto = dDayService.createDDay(
            loginMember = loginMember(TestData.member),
            dDaySaveDto = DDaySaveDto(
                title = "Anniversary",
                date = LocalDate.now().plusDays(5),
                isPrivate = false
            )
        )

        val saved = dDayRepository.findById(dto.id).orElseThrow()
        assertThat(saved.title).isEqualTo("Anniversary")
        assertThat(saved.isPrivate).isFalse
    }

    @Test
    fun `findDDay allows owner for private event`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Private",
                date = LocalDate.now().plusDays(1),
                isPrivate = true
            )
        )

        val result = dDayService.findDDay(loginMember(TestData.member), event.id!!)

        assertThat(result.id).isEqualTo(event.id)
        assertThat(result.isPrivate).isTrue
    }

    @Test
    fun `findDDay blocks non-owner for private event`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Private",
                date = LocalDate.now().plusDays(1),
                isPrivate = true
            )
        )

        assertThrows<AuthException> {
            dDayService.findDDay(loginMember(TestData.member2), event.id!!)
        }
    }

    @Test
    fun `findDDays returns only public events for non-owner`() {
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Public",
                date = LocalDate.now().plusDays(2),
                isPrivate = false
            )
        )
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Private",
                date = LocalDate.now().plusDays(3),
                isPrivate = true
            )
        )

        val result = dDayService.findDDays(loginMember(TestData.member2), TestData.member.id!!)

        assertThat(result).hasSize(1)
        assertThat(result.first().title).isEqualTo("Public")
    }

    @Test
    fun `findDDays returns all events for owner`() {
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Public",
                date = LocalDate.now().plusDays(2),
                isPrivate = false
            )
        )
        dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Private",
                date = LocalDate.now().plusDays(3),
                isPrivate = true
            )
        )

        val result = dDayService.findDDays(loginMember(TestData.member), TestData.member.id!!)

        assertThat(result).hasSize(2)
    }

    @Test
    fun `updateDDay requires id`() {
        assertThrows<IllegalArgumentException> {
            dDayService.updateDDay(
                loginMember(TestData.member),
                DDaySaveDto(
                    id = null,
                    title = "Update",
                    date = LocalDate.now().plusDays(1),
                    isPrivate = false
                )
            )
        }
    }

    @Test
    fun `updateDDay updates fields for owner`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Before",
                date = LocalDate.now().plusDays(1),
                isPrivate = false
            )
        )

        val result = dDayService.updateDDay(
            loginMember(TestData.member),
            DDaySaveDto(
                id = event.id,
                title = "After",
                date = LocalDate.now().plusDays(10),
                isPrivate = true
            )
        )

        assertThat(result.title).isEqualTo("After")
        val updated = dDayRepository.findById(event.id!!).orElseThrow()
        assertThat(updated.isPrivate).isTrue
    }

    @Test
    fun `updateDDay blocks non-owner`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Before",
                date = LocalDate.now().plusDays(1),
                isPrivate = false
            )
        )

        assertThrows<AuthException> {
            dDayService.updateDDay(
                loginMember(TestData.member2),
                DDaySaveDto(
                    id = event.id,
                    title = "After",
                    date = LocalDate.now().plusDays(10),
                    isPrivate = true
                )
            )
        }
    }

    @Test
    fun `deleteDDay removes event for owner`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Delete",
                date = LocalDate.now().plusDays(1),
                isPrivate = false
            )
        )

        dDayService.deleteDDay(loginMember(TestData.member), event.id!!)

        assertThat(dDayRepository.findById(event.id!!)).isEmpty
    }

    @Test
    fun `deleteDDay blocks non-owner`() {
        val event = dDayRepository.save(
            DDayEvent(
                member = TestData.member,
                title = "Delete",
                date = LocalDate.now().plusDays(1),
                isPrivate = false
            )
        )

        assertThrows<AuthException> {
            dDayService.deleteDDay(loginMember(TestData.member2), event.id!!)
        }
    }
}
