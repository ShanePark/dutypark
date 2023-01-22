package com.tistory.shanepark.dutypark.common.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.repository.RefreshTokenRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import java.time.LocalDateTime

@SpringBootTest
class BaseTimeEntityTest {

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var departmentRepository: DepartmentRepository

    @Test
    fun test() {
        val department = Department("testDept")
        departmentRepository.save(department)
        val member = Member(department, "test", "test", "1234")
        memberRepository.save(member)

        val refreshToken = RefreshToken(member, LocalDateTime.now())
        refreshTokenRepository.save(refreshToken)

        assertThat(refreshToken.createdDate).isNotNull
        assertThat(refreshToken.modifiedDate).isNotNull
        assertThat(refreshToken.createdDate).isSameAs(refreshToken.modifiedDate)

        refreshToken.validUntil = LocalDateTime.now()

        val saved = refreshTokenRepository.save(refreshToken)
        assertThat(saved.modifiedDate).isAfter(refreshToken.createdDate)
    }

}
