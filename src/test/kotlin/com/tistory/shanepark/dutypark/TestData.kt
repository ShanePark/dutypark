package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.MemberService
import org.springframework.context.ApplicationListener
import org.springframework.context.event.ContextRefreshedEvent
import org.springframework.stereotype.Component

@Component
class TestData(
    private val departmentRepository: DepartmentRepository,
    private val memberRepository: MemberRepository,
    private val memberService: MemberService,
    private val dutyTypeRepository: DutyTypeRepository,
) : ApplicationListener<ContextRefreshedEvent> {

    override fun onApplicationEvent(event: ContextRefreshedEvent) {
        initTestDepartment()
        initTestMember()
        initDutyTypes()
    }

    private fun initDutyTypes() {
        dutyTypeRepository.saveAll(dutyTypes)
    }

    private fun initTestMember() {
        listOf(member, member2).forEach {
            val memberCreateDto = MemberCreateDto(
                name = it.name,
                email = it.email,
                password = testPass,
            )
            val saved = memberService.createMember(memberCreateDto)
            saved.department = department
            memberRepository.save(saved)

            it.id = saved.id
            it.password = saved.password
        }
    }

    private fun initTestDepartment() {
        departmentRepository.saveAll(listOf(department, department2))
    }

    companion object {
        val department = Department("testDept1")
        val department2 = Department("testDept2")
        const val testPass = "1234"

        var member = Member(
            email = "test@duty.park",
            name = "dummy",
            password = testPass
        )
        var member2 = Member(
            email = "test2@duty.park",
            name = "dummy",
            password = testPass
        )

        val dutyTypes = listOf(
            DutyType("오전", 0, department, Color.BLUE),
            DutyType("오후", 1, department, Color.RED),
            DutyType("야간", 2, department, Color.GREEN),
        )

    }

}
