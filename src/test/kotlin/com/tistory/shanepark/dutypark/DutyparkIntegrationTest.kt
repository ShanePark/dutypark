package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.MemberService
import jakarta.persistence.EntityManager
import org.junit.jupiter.api.BeforeEach
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.annotation.Transactional

@SpringBootTest
@Transactional
class DutyparkIntegrationTest {

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var memberService: MemberService

    @Autowired
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    lateinit var entityManager: EntityManager

    @BeforeEach
    fun init() {
        initTestDepartment()
        initDutyTypes()
        initTestMember()
    }

    private fun initTestDepartment() {
        TestData.department = departmentRepository.save(Department("testDept1"))
        TestData.department2 = departmentRepository.save(Department("testDept2"))
    }

    private fun initDutyTypes() {
        TestData.dutyTypes.clear()
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("오전", 0, TestData.department)))
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("오후", 1, TestData.department)))
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("야간", 2, TestData.department)))
    }

    private fun initTestMember() {
        for (i in 1..2) {
            val memberCreateDto = MemberCreateDto(
                name = "dummy$i",
                email = "test$i@duty.park",
                password = TestData.testPass,
            )
            val saved = memberService.createMember(memberCreateDto)
            TestData.department.addMember(saved)
            memberRepository.save(saved)
            if (i == 1) {
                TestData.member = saved
            } else {
                TestData.member2 = saved
            }
        }
    }

    companion object {
        val TestData = TestData()
    }

    class TestData {
        var department = Department("dummy")
        var department2 = Department("dummy")
        val testPass = "1234"

        var member: Member = Member("", "", "")
        var member2: Member = Member("", "", "")

        val dutyTypes = mutableListOf<DutyType>()
    }

}