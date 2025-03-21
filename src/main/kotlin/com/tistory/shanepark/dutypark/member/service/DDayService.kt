package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DDayService(
    private val memberRepository: MemberRepository,
    private val dDayRepository: DDayRepository
) {
    val log = logger()

    fun createDDay(loginMember: LoginMember, dDaySaveDto: DDaySaveDto): DDayDto {
        val member = memberRepository.findById(loginMember.id).orElseThrow()

        val dDayEvent = DDayEvent(
            member = member,
            title = dDaySaveDto.title,
            date = dDaySaveDto.date,
            isPrivate = dDaySaveDto.isPrivate,
        )
        dDayRepository.save(dDayEvent)
        return DDayDto.of(dDayEvent)
    }

    @Transactional(readOnly = true)
    fun findDDay(loginMember: LoginMember?, id: Long): DDayDto {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        if (dDayEvent.isPrivate) {
            authenticationCheck(dDayEvent, loginMember)
        }
        return DDayDto.of(dDayEvent)
    }

    @Transactional(readOnly = true)
    fun findDDays(loginMember: LoginMember?, memberId: Long): List<DDayDto> {
        val member = memberRepository.findById(memberId).orElseThrow()
        val isLoginMember = loginMember?.id == memberId
        return dDayRepository.findAllByMemberOrderByDate(member)
            .filter { isLoginMember || !it.isPrivate }
            .map { DDayDto.of(it) }
    }

    fun updateDDay(loginMember: LoginMember, dDaySaveDto: DDaySaveDto): DDayDto {
        val id = dDaySaveDto.id ?: throw IllegalArgumentException("DDay ID must not be null")
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember)
        dDayEvent.title = dDaySaveDto.title
        dDayEvent.date = dDaySaveDto.date
        dDayEvent.isPrivate = dDaySaveDto.isPrivate
        return DDayDto.of(dDayEvent)
    }

    fun deleteDDay(loginMember: LoginMember, id: Long) {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember)
        dDayRepository.delete(dDayEvent)
    }

    private fun authenticationCheck(
        dDayEvent: DDayEvent,
        loginMember: LoginMember?
    ) {
        if (dDayEvent.member.id != loginMember?.id) {
            log.warn("login member and d-day event member does not match: login:${loginMember?.id}, dDayEvent:${dDayEvent.id}")
            throw AuthException("Can't access other member's d-day event")
        }
    }

}
