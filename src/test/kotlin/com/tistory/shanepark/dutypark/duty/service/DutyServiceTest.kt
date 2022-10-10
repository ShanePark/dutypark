package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.PasswordEncoder
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
import org.springframework.transaction.annotation.Transactional

@SpringBootTest
@Transactional
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

    val passwordEncoder = PasswordEncoder()
    val department = Department("개발팀")
    val password = "test"
    val member = Member(department, "test", passwordEncoder.encode(password))
    val dutyTypes = listOf(
        DutyType("오전", 0, department, Color.BLUE),
        DutyType("오후", 1, department, Color.RED),
        DutyType("야간", 2, department, Color.GREEN),
    )

    @BeforeAll
    fun beforeAll() {
        departmentRepository.save(department)
        memberRepository.save(member);
        dutyTypes.forEach { dutyTypeRepository.save(it) }
    }

    @BeforeEach
    fun beforeEach() {
        dutyRepository.deleteAll()
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
                password = password
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
                password = password
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
                password = password
            )
        )
        assertThat(dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]).isNull()
    }

    @Test
    @DisplayName("incorrect password")
    fun password() {
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        assertThrows<IllegalArgumentException> {
            dutyService.update(
                DutyUpdateDto(
                    year = 2022,
                    month = 10,
                    day = 10,
                    dutyTypeId = null,
                    memberId = member.id!!,
                    password = "wrong pass"
                )
            )
        }

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
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
                    password = "wrong pass"
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
                    password = password
                )
            )
        }

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

}
