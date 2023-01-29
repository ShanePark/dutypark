package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.*
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import java.time.LocalDate


@SpringBootTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class DDayServiceTest {

    @Autowired
    lateinit var dDayService: DDayService

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Autowired
    lateinit var dDayRepository: DDayRepository

    val dept = Department("dummy")

    var member = Member(
        email = "test@duty.park",
        department = dept,
        name = "dummy",
        password = "dummy"
    )

    var member2 = Member(
        email = "test2@duty.park",
        department = dept,
        name = "dummy",
        password = "dummy"
    )

    @BeforeAll
    fun beforeAll() {
        departmentRepository.save(dept)
        memberRepository.save(member)
        memberRepository.save(member2)
    }

    @BeforeEach
    fun beforeEach() {
        dDayRepository.deleteAll()
    }

    @Test
    fun createDDay() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        assertThat(createDDay.id).isNotNull
        assertThat(dDayRepository.findAll().size).isEqualTo(1)
    }

    @Test
    fun `Create fail if login Member has Problem`() {
        assertThrows<NoSuchElementException> {
            dDayService.createDDay(
                loginMember = LoginMember(id = -1, email = "", name = "", 0, "dept"),
                title = "test",
                date = LocalDate.now().plusDays(3),
                isPrivate = false
            )
        }
    }

    @Test
    fun findDDay() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        val findDDay = dDayService.findDDay(loginMember, createDDay.id!!)
        assertThat(findDDay.id).isEqualTo(createDDay.id)
        assertThat(findDDay.daysLeft).isEqualTo(3)

        val dDayToday = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now(),
            isPrivate = false
        )
        val findDDayToday = dDayService.findDDay(loginMember, dDayToday.id!!)
        assertThat(findDDayToday.daysLeft).isEqualTo(0)
    }

    @Test
    fun `can't find private D-day of other person`() {
        val loginMember = getLoginMember(member)
        val loginMember2 = getLoginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = true
        )
        assertThrows<AuthenticationException> {
            dDayService.findDDay(loginMember2, createDDay.id!!)
        }
    }

    @Test
    fun findDDays() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(5),
            isPrivate = false
        )
        val findDDays = dDayService.findDDays(loginMember, member.id!!)
        assertThat(findDDays.size).isEqualTo(2)
        assertThat(findDDays[0].id).isEqualTo(createDDay.id)
        assertThat(findDDays.map { it.id }).containsAll(listOf(createDDay.id, createDDay2.id))
    }

    @Test
    fun `find D-Day by another person, private ones are not show`() {
        val loginMember = getLoginMember(member)
        val loginMember2 = getLoginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = true
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(5),
            isPrivate = false
        )
        val findDDays = dDayService.findDDays(loginMember2, member.id!!)
        assertThat(findDDays.size).isEqualTo(1)
        assertThat(findDDays[0].id).isEqualTo(createDDay2.id)
        assertThat(findDDays.map { it.id }).doesNotContain(createDDay.id)
    }

    @Test
    fun updateDDay() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        dDayService.updateDDay(
            loginMember = loginMember,
            id = createDDay.id!!,
            title = "test2",
            date = LocalDate.now().plusDays(5),
            isPrivate = true
        )

        val updateDDay = dDayService.findDDay(loginMember, createDDay.id!!)
        assertThat(updateDDay.title).isEqualTo("test2")
        assertThat(updateDDay.date).isEqualTo(LocalDate.now().plusDays(5))
        assertThat(updateDDay.isPrivate).isEqualTo(true)
    }

    @Test
    fun `Can't update other member's D-Day event`() {
        val loginMember = getLoginMember(member)
        val loginMember2 = getLoginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        assertThrows<AuthenticationException> {
            dDayService.updateDDay(
                loginMember = loginMember2,
                id = createDDay.id!!,
                title = "test2",
                date = LocalDate.now().plusDays(5),
                isPrivate = true
            )
        }
    }

    @Test
    fun updatePrivacy() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        dDayService.updatePrivacy(loginMember, createDDay.id!!, true)
        val updateDDay = dDayService.findDDay(loginMember, createDDay.id!!)
        assertThat(updateDDay.isPrivate).isEqualTo(true)
        assertThat(updateDDay.title).isEqualTo("test")
        assertThat(updateDDay.date).isEqualTo(LocalDate.now().plusDays(3))
    }

    @Test
    fun rearrangeOrders() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(5),
            isPrivate = false
        )
        val createDDay3 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(7),
            isPrivate = false
        )
        val createDDay4 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(9),
            isPrivate = false
        )
        val createDDay5 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(11),
            isPrivate = false
        )
        dDayRepository.saveAll(listOf(createDDay, createDDay2, createDDay3, createDDay4, createDDay5))
        assertThat(createDDay.position).isEqualTo(0)
        assertThat(createDDay2.position).isEqualTo(1)
        assertThat(createDDay3.position).isEqualTo(2)
        assertThat(createDDay4.position).isEqualTo(3)
        assertThat(createDDay5.position).isEqualTo(4)
        dDayService.rearrangeOrders(
            loginMember,
            0,
            listOf(createDDay5.id!!, createDDay4.id!!, createDDay3.id!!, createDDay2.id!!, createDDay.id!!)
        )
        val findDDays = dDayService.findDDays(loginMember, member.id!!)
        assertThat(findDDays[0].id).isEqualTo(createDDay5.id)
        assertThat(findDDays[1].id).isEqualTo(createDDay4.id)
        assertThat(findDDays[2].id).isEqualTo(createDDay3.id)
        assertThat(findDDays[3].id).isEqualTo(createDDay2.id)
        assertThat(findDDays[4].id).isEqualTo(createDDay.id)
    }

    @Test
    fun `can't rearrange if any of D-Day event is other member's`() {
        val loginMember = getLoginMember(member)
        val loginMember2 = getLoginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(5),
            isPrivate = false
        )
        val createDDay3 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(7),
            isPrivate = false
        )
        val createDDay4 = dDayService.createDDay(
            loginMember = loginMember2,
            title = "test",
            date = LocalDate.now().plusDays(9),
            isPrivate = false
        )
        val createDDay5 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(11),
            isPrivate = false
        )
        dDayRepository.saveAll(listOf(createDDay, createDDay2, createDDay3, createDDay4, createDDay5))
        assertThrows<AuthenticationException> {
            dDayService.rearrangeOrders(
                loginMember,
                0,
                listOf(createDDay5.id!!, createDDay4.id!!, createDDay3.id!!, createDDay2.id!!, createDDay.id!!)
            )
        }
    }

    @Test
    fun `can't rearrange if prefix is not valid`() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        val createDDay2 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(5),
            isPrivate = false
        )
        val createDDay3 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(7),
            isPrivate = false
        )
        val createDDay4 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(9),
            isPrivate = false
        )
        val createDDay5 = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(11),
            isPrivate = false
        )
        dDayService.rearrangeOrders(
            loginMember,
            2,
            listOf(createDDay3.id!!, createDDay4.id!!)
        )
        assertThrows<IllegalArgumentException> {
            dDayService.rearrangeOrders(
                loginMember,
                3,
                listOf(createDDay3.id!!, createDDay4.id!!)
            )
        }
    }

    @Test
    fun deleteDDay() {
        val loginMember = getLoginMember(member)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        assertThat(dDayRepository.findAll()).hasSize(1)
        dDayService.deleteDDay(loginMember, createDDay.id!!)
        assertThat(dDayRepository.findAll()).hasSize(0)
    }

    @Test
    fun `can't delete D-day event of other member`() {
        val loginMember = getLoginMember(member)
        val loginMember2 = getLoginMember(member2)
        val createDDay = dDayService.createDDay(
            loginMember = loginMember,
            title = "test",
            date = LocalDate.now().plusDays(3),
            isPrivate = false
        )
        assertThrows<AuthenticationException> {
            dDayService.deleteDDay(loginMember2, createDDay.id!!)
        }
    }

    private fun getLoginMember(member: Member): LoginMember {
        return LoginMember(
            id = member.id!!,
            email = member.email,
            name = member.name,
            0, "dept"
        )
    }
}
