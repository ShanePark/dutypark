package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color.*
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.ApplicationListener
import org.springframework.context.event.ContextRefreshedEvent
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Component

@Component
class DefaultDataInitializer(
    private val departmentRepository: DepartmentRepository,
    private val memberRepository: MemberRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val passwordEncoder: PasswordEncoder,
    @param:Value("\${spring.profiles.active:default}")
    val activeProfile: String
) : ApplicationListener<ContextRefreshedEvent?> {

    override fun onApplicationEvent(event: ContextRefreshedEvent) {
        if (activeProfile == "test" || memberRepository.count() > 0)
            return
        jennyInit()
        paulInit()
        testerInit()
    }

    private fun jennyInit() {
        val department = Department("케익부")
        departmentRepository.save(department)
        val jenny = Member(
            name = "이동현",
            department = department,
            email = "jen@duty.park",
            password = passwordEncoder.encode("1234")
        )
        memberRepository.save(jenny);

        val open = dutyTypeRepository.save(DutyType(name = "새벽", position = 0, department = department, PURPLE))
        val mid = dutyTypeRepository.save(DutyType(name = "정출", position = 1, department = department, BLUE))
        val close = dutyTypeRepository.save(DutyType(name = "마감", position = 2, department = department, RED))

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
        val paul = Member(
            name = "박재현",
            department = department2,
            email = "jh@duty.park",
            password = passwordEncoder.encode("1234")
        )
        memberRepository.save(paul)

        dutyTypeRepository.save(DutyType(name = "데이", position = 0, department = department2, BLUE))
        dutyTypeRepository.save(DutyType(name = "이브", position = 1, department = department2, PURPLE))
        dutyTypeRepository.save(DutyType(name = "나이트", position = 2, department = department2, RED))
    }

    private fun testerInit() {
        val department = departmentRepository.findAll()[0]
        val tester = Member(
            name = "테스트",
            department = department,
            email = "test@duty.park",
            password = passwordEncoder.encode("1234")
        )
        memberRepository.save(tester);
    }
}
