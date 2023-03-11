package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
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

    val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    fun createDDay(loginMember: LoginMember, dDaySaveDto: DDaySaveDto): DDayEvent {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val maxPosition = dDayRepository.findMaxPositionByMember(member)

        val dDayEvent = DDayEvent(
            member = member,
            title = dDaySaveDto.title,
            date = dDaySaveDto.date,
            isPrivate = dDaySaveDto.isPrivate,
            position = maxPosition + 1
        )
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

    fun rearrangeOrders(loginMember: LoginMember, prefix: Long, ids: List<Long>) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()

        val maxPosition = dDayRepository.findMaxPositionByMember(member)
        val countByMember = dDayRepository.countByMember(member)
        if (maxPosition >= countByMember) { // if some d-day event is deleted, rearrange all d-day events
            dDayRepository.findAllByMemberOrderByPosition(member)
                .forEachIndexed { index, dDayEvent ->
                    dDayEvent.position = index.toLong()
                }
        }

        val affectedDDays = dDayRepository.findAllById(ids)

        // validation. if any of ids is not in the range of prefix ~ prefix + ids.size, throw exception
        affectedDDays.map { it.position }
            .any { position -> position < prefix || prefix + ids.size <= position }
            .let {
                if (it) {
                    log.warn("Invalid ids or prefix. ids: $ids, prefix: $prefix")
                    throw IllegalArgumentException("Invalid ids or prefix. ids: $ids, prefix: $prefix")
                }
            }
        // validation. if any of ids is not belong to loginMember, throw exception
        affectedDDays.map { it.member.id }
            .any { it != member.id }.let {
                if (it) {
                    log.warn("Can't access other member's d-day event. ids: $ids, loginMember: $loginMember")
                    throw DutyparkAuthException("Can't access other member's d-day event")
                }
            }

        // update position
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
            throw DutyparkAuthException("Can't access other member's d-day event")
        }
    }

}
