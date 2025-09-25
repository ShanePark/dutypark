package com.tistory.shanepark.dutypark

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.JwtProvider
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import jakarta.persistence.EntityManager
import org.junit.jupiter.api.BeforeEach
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.annotation.Transactional

@SpringBootTest
@Transactional
class DutyparkIntegrationTest {

    @Autowired
    lateinit var teamRepository: TeamRepository

    @Autowired
    lateinit var memberRepository: MemberRepository

    @Autowired
    lateinit var memberService: MemberService

    @Autowired
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    lateinit var friendRelationRepository: FriendRelationRepository

    @Autowired
    lateinit var em: EntityManager

    @Autowired
    lateinit var jwtProvider: JwtProvider

    val objectMapper: ObjectMapper = TestUtils.jsr310ObjectMapper()

    @BeforeEach
    fun init() {
        initTestTeam()
        initDutyTypes()
        initTestMember()
        em.flush()
        em.clear()
    }

    private fun initTestTeam() {
        TestData.team = teamRepository.save(Team("testTeam1"))
        TestData.team2 = teamRepository.save(Team("testTeam2"))
    }

    private fun initDutyTypes() {
        TestData.dutyTypes.clear()
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("오전", 0, TestData.team, "#ffb3ba")))
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("오후", 1, TestData.team, "#ffdfba")))
        TestData.dutyTypes.add(dutyTypeRepository.save(DutyType("야간", 2, TestData.team, "#ffffba")))
    }

    private fun initTestMember() {
        for (i in 1..2) {
            val memberCreateDto = MemberCreateDto(
                name = "dummy$i",
                email = "test$i@duty.park",
                password = TestData.testPass,
            )
            val saved = memberService.createMember(memberCreateDto)
            TestData.team.addMember(saved)
            memberRepository.save(saved)
            if (i == 1) {
                TestData.member = saved
            } else {
                TestData.member2 = saved
            }
        }
        TestData.admin = memberService.createMember(
            MemberCreateDto(
                name = "admin",
                email = "admin@email.com",
                password = TestData.testPass,
            )
        )
    }

    companion object {
        val TestData = TestData()
    }

    class TestData {
        var team = Team("dummy")
        var team2 = Team("dummy")
        val testPass = "1234"

        var member: Member = Member("", "", "")
        var member2: Member = Member("", "", "")
        var admin: Member = Member("", "", "")

        val dutyTypes = mutableListOf<DutyType>()
    }

    fun getJwt(member: Member): String {
        return jwtProvider.createToken(member)
    }

    fun loginMember(member: Member): LoginMember {
        return LoginMember(
            id = member.id!!,
            email = member.email,
            name = member.name,
            team = member.team?.name,
            isAdmin = false
        )
    }

    protected fun updateVisibility(target: Member, visibility: Visibility) {
        target.calendarVisibility = visibility
        memberRepository.save(target)
    }

    protected fun makeThemFriend(member1: Member, member2: Member) {
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

}
