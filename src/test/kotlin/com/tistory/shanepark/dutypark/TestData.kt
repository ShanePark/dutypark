package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.context.ApplicationListener
import org.springframework.context.event.ContextRefreshedEvent
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Component

@Component
class TestData(
    private val departmentRepository: DepartmentRepository,
    private val memberRepository: MemberRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val passwordEncoder: PasswordEncoder
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
            it.password = passwordEncoder.encode(it.password)
            memberRepository.saveAll(mutableListOf(member, member2))
        }
        member.password = "1234"
        member2.password = "1234"
    }

    private fun initTestDepartment() {
        departmentRepository.saveAll(listOf(department, department2))
    }

    companion object {
        val department = Department("testDept1")
        val department2 = Department("testDept2")

        val member = Member(
            email = "test@duty.park",
            department = department,
            name = "dummy",
            password = "1234"
        )
        val member2 = Member(
            email = "test2@duty.park",
            department = department,
            name = "dummy",
            password = "1234"
        )

        val dutyTypes = listOf(
            DutyType("오전", 0, department, Color.BLUE),
            DutyType("오후", 1, department, Color.RED),
            DutyType("야간", 2, department, Color.GREEN),
        )

    }

}
