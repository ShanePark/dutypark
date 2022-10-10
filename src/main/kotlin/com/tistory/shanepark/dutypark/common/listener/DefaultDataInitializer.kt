package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.common.PBKDF2PasswordEncoder
import com.tistory.shanepark.dutypark.duty.domain.Duty
import com.tistory.shanepark.dutypark.duty.domain.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color.*
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.Department
import com.tistory.shanepark.dutypark.member.domain.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.context.ApplicationListener
import org.springframework.context.event.ContextRefreshedEvent
import org.springframework.stereotype.Component

@Component
class DefaultDataInitializer(
    private val departmentRepository: DepartmentRepository,
    private val memberRepository: MemberRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val passwordEncoder: PBKDF2PasswordEncoder
) : ApplicationListener<ContextRefreshedEvent?> {

    override fun onApplicationEvent(event: ContextRefreshedEvent) {
        if (memberRepository.findMemberByName("이동현") != null)
            return

        jennyInit()
        paulInit()

    }

    private fun jennyInit() {
        val department = Department("케익부")
        departmentRepository.save(department)
        val jenny = Member(name = "이동현", department = department, password = passwordEncoder.encode("1234"))
        memberRepository.save(jenny);

        val open = dutyTypeRepository.save(DutyType(name = "새벽", index = 0, department = department, PURPLE))
        val mid = dutyTypeRepository.save(DutyType(name = "정출", index = 1, department = department, BLUE))
        val close = dutyTypeRepository.save(DutyType(name = "마감", index = 2, department = department, RED))

        dutyRepository.save(
            Duty(
                member = jenny,
                dutyType = open, dutyYear = 2022, dutyMonth = 10, dutyDay = 7, memo = "7am"
            )
        )
        dutyRepository.save(
            Duty(
                member = jenny,
                dutyType = close, dutyYear = 2022, dutyMonth = 10, dutyDay = 9
            )
        )
        dutyRepository.save(
            Duty(
                member = jenny,
                dutyType = mid, dutyYear = 2022, dutyMonth = 10, dutyDay = 10
            )
        )
    }

    private fun paulInit() {
        val department2 = Department("PACU")
        departmentRepository.save(department2)
        val paul = Member(name = "박재현", department = department2, password = passwordEncoder.encode("1234"))
        memberRepository.save(paul)

        dutyTypeRepository.save(DutyType(name = "데이", index = 0, department = department2, BLUE))
        dutyTypeRepository.save(DutyType(name = "이브", index = 1, department = department2, PURPLE))
        dutyTypeRepository.save(DutyType(name = "나이트", index = 2, department = department2, RED))
    }
}
