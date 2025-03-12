package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
    fun createDDay() {
        val member = TestData.member
        val loginMember = loginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        assertThat(createDDay.id).isNotNull
        assertThat(dDayRepository.findAll().size).isEqualTo(1)
    }

    @Test
    fun `Create fail if login Member has Problem`() {
        assertThrows<NoSuchElementException> {
            dDayService.createDDay(
                loginMember = LoginMember(id = -1, email = "", name = "", "dept", isAdmin = false),
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
        val member = TestData.member
        val loginMember = loginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        val findDDay = dDayService.findDDay(loginMember, createDDay.id!!)
        assertThat(findDDay.id).isEqualTo(createDDay.id)
        assertThat(findDDay.daysLeft).isEqualTo(3)

        val dDayToday = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now(),
                isPrivate = false
            )
        )
        val findDDayToday = dDayService.findDDay(loginMember, dDayToday.id!!)
        assertThat(findDDayToday.daysLeft).isEqualTo(0)
    }

    @Test
    fun `can't find private D-day of other person`() {
        val member = TestData.member
        val member2 = TestData.member2
        val loginMember = loginMember(member)
        val loginMember2 = loginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = true
            )
        )
        assertThrows<DutyparkAuthException> {
            dDayService.findDDay(loginMember2, createDDay.id!!)
        }
    }

    @Test
    fun findDDays() {
        val member = TestData.member
        val loginMember = loginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(5),
                isPrivate = false
            )
        )
        val findDDays = dDayService.findDDays(loginMember, member.id!!)
        assertThat(findDDays.size).isEqualTo(2)
        assertThat(findDDays[0].id).isEqualTo(createDDay.id)
        assertThat(findDDays.map { it.id }).containsAll(listOf(createDDay.id, createDDay2.id))
    }

    @Test
    fun `find D-Day by another person, private ones are not show`() {
        val member = TestData.member
        val member2 = TestData.member2
        val loginMember = loginMember(member)
        val loginMember2 = loginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = true
            )
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(5),
                isPrivate = false
            )
        )
        val findDDays = dDayService.findDDays(loginMember2, member.id!!)
        assertThat(findDDays.size).isEqualTo(1)
        assertThat(findDDays[0].id).isEqualTo(createDDay2.id)
        assertThat(findDDays.map { it.id }).doesNotContain(createDDay.id)
    }

    @Test
    fun updateDDay() {
        val member = TestData.member
        val loginMember = loginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        val updateDDayDto = DDaySaveDto(
            id = createDDay.id,
            title = "test2",
            date = LocalDate.now().plusDays(5),
            isPrivate = true
        )
        dDayService.updateDDay(
            loginMember = loginMember,
            dDaySaveDto = updateDDayDto
        )

        val updateDDay = dDayService.findDDay(loginMember, createDDay.id!!)
        assertThat(updateDDay.title).isEqualTo("test2")
        assertThat(updateDDay.date).isEqualTo(LocalDate.now().plusDays(5))
        assertThat(updateDDay.isPrivate).isEqualTo(true)
    }

    @Test
    fun `Can't update other member's D-Day event`() {
        val member = TestData.member
        val member2 = TestData.member2
        val loginMember = loginMember(member)
        val loginMember2 = loginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        val updateDDayDto = DDaySaveDto(
            id = createDDay.id,
            title = "test2",
            date = LocalDate.now().plusDays(5),
            isPrivate = true
        )
        assertThrows<DutyparkAuthException> {
            dDayService.updateDDay(
                loginMember = loginMember2,
                dDaySaveDto = updateDDayDto
            )
        }
    }

    @Test
    fun deleteDDay() {
        val member = TestData.member
        val loginMember = loginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        assertThat(dDayRepository.findAll()).hasSize(1)
        dDayService.deleteDDay(loginMember, createDDay.id!!)
        assertThat(dDayRepository.findAll()).hasSize(0)
    }

    @Test
    fun `can't delete D-day event of other member`() {
        val member = TestData.member
        val member2 = TestData.member2
        val loginMember = loginMember(member)
        val loginMember2 = loginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            dDaySaveDto = DDaySaveDto(
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        )
        assertThrows<DutyparkAuthException> {
            dDayService.deleteDDay(loginMember2, createDDay.id!!)
        }
    }

}
