package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.*
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder

@SpringBootTest
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
internal class DutyServiceTest {

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var dutyTypeRepository: DutyTypeRepository

    val passwordEncoder = BCryptPasswordEncoder()
    val email = "test@duty.park"
    val password = "1234"
    val dummy = "dummy"

    var member = Member(
        email = dummy,
        department = Department("dummy"),
        name = "dummy",
        password = passwordEncoder.encode(dummy)
    )
    var dutyTypes = emptyList<DutyType>()

    @BeforeEach
    fun beforeEach() {
        val dept = departmentRepository.save(Department("개발팀"))

        val member = Member(dept, "test", email, passwordEncoder.encode(password))
        val department = member.department
        val dutyTypes = listOf(
            DutyType("오전", 0, department, Color.BLUE),
            DutyType("오후", 1, department, Color.RED),
            DutyType("야간", 2, department, Color.GREEN),
        )

        memberRepository.save(member)
        dutyTypeRepository.saveAll(dutyTypes)

        this.member = member
        this.dutyTypes = dutyTypes
    }

    @AfterEach
    fun afterEach() {
        dutyRepository.deleteAll()
        dutyTypeRepository.deleteAll()
        memberRepository.deleteAll()
        departmentRepository.deleteAll()
    }

    @Test
    @DisplayName("create new duty")
    fun create() {
        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = dutyTypes[0].id,
                memberId = member.id!!,
            )
        )

        val dutyDto = dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]
        assertThat(dutyDto).isNotNull
        dutyDto?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }

    }

    @Test
    @DisplayName("change original duty to new duty")
    fun update() {
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[1].name)
        }

    }

    @Test
    @DisplayName("delete original duty")
    fun delete() {
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
        assertThat(dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]).isNull()
    }

    @Test
    @DisplayName("wrong member Id")
    fun wrongMemberId() {
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

    @Test
    @DisplayName("wrong duty Type Id")
    fun wrongDutyTypeId() {
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

}
