package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate

@Service
@Transactional
class DDayService(
    private val memberRepository: MemberRepository,
    private val dDayRepository: DDayRepository
) {

    fun createDDay(loginMember: LoginMember, title: String, date: LocalDate, isPrivate: Boolean): DDayEvent {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val countByMember = dDayRepository.countByMember(member)
        val dDayEvent = DDayEvent(member = member, title, date, isPrivate, countByMember)
        return dDayRepository.save(dDayEvent)
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
        return dDayRepository.findAllByMemberOrderByPosition(member)
            .filter { isLoginMember || !it.isPrivate }
            .map { DDayDto.of(it) }
    }

    fun rearrangeOrders(prefix: Long, ids: List<Long>) {
        ids.forEachIndexed { index, id ->
            val dDayEvent = dDayRepository.findById(id).orElseThrow()
            dDayEvent.position = prefix + index.toLong()
        }
    }

    fun updateDDay(loginMember: LoginMember, id: Long, title: String, date: LocalDate, isPrivate: Boolean) {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember)
        dDayEvent.title = title
        dDayEvent.date = date
        dDayEvent.isPrivate = isPrivate
    }

    fun updatePrivacy(loginMember: LoginMember, id: Long, isPrivate: Boolean) {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember)
        dDayEvent.isPrivate = isPrivate
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
            throw AuthenticationException("Can't access other member's d-day event")
        }
    }

}
