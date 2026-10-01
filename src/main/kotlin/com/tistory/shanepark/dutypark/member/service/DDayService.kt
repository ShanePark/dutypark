package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DDayService(
    private val memberRepository: MemberRepository,
    private val dDayRepository: DDayRepository,
    private val friendService: FriendService,
    private val publicContentService: PublicContentService,
) {
    val log = logger()

    fun createDDay(loginMember: LoginMember, dDaySaveDto: DDaySaveDto): DDayDto {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        validatePublicTitle(dDaySaveDto)

        val dDayEvent = DDayEvent(
            member = member,
            title = dDaySaveDto.title,
            date = dDaySaveDto.date,
            isPrivate = dDaySaveDto.isPrivate,
        )
        dDayRepository.save(dDayEvent)
        log.auditEventAfterCommit("dday.created", loginMember.toAuditActor(),
            target = mapOf("type" to "DDayEvent", "id" to dDayEvent.id, "ownerId" to loginMember.id),
            details = mapOf("date" to dDayEvent.date, "isPrivate" to dDayEvent.isPrivate))
        return DDayDto.of(dDayEvent)
    }

    @Transactional(readOnly = true)
    fun findDDay(loginMember: LoginMember?, id: Long): DDayDto {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        friendService.checkVisibility(loginMember, dDayEvent.member)
        if (dDayEvent.isPrivate) {
            authenticationCheck(dDayEvent, loginMember, operation = "view")
        }
        return DDayDto.of(dDayEvent)
    }

    @Transactional(readOnly = true)
    fun findDDays(loginMember: LoginMember?, memberId: Long): List<DDayDto> {
        val member = memberRepository.findById(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member)
        val isLoginMember = loginMember?.id == memberId
        return dDayRepository.findAllByMemberOrderByDate(member)
            .filter { isLoginMember || !it.isPrivate }
            .map { DDayDto.of(it) }
    }

    fun updateDDay(loginMember: LoginMember, dDaySaveDto: DDaySaveDto): DDayDto {
        val id = dDaySaveDto.id ?: throw IllegalArgumentException("DDay ID must not be null")
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember, operation = "update")
        validatePublicTitle(dDaySaveDto)
        val before = mapOf("date" to dDayEvent.date, "isPrivate" to dDayEvent.isPrivate, "titleChanged" to false)
        val titleChanged = dDayEvent.title != dDaySaveDto.title
        dDayEvent.title = dDaySaveDto.title
        dDayEvent.date = dDaySaveDto.date
        dDayEvent.isPrivate = dDaySaveDto.isPrivate
        log.auditChangeAfterCommit("dday.updated", loginMember.toAuditActor(),
            target = mapOf("type" to "DDayEvent", "id" to dDayEvent.id, "ownerId" to loginMember.id),
            before = before,
            after = mapOf("date" to dDayEvent.date, "isPrivate" to dDayEvent.isPrivate, "titleChanged" to titleChanged))
        return DDayDto.of(dDayEvent)
    }

    fun deleteDDay(loginMember: LoginMember, id: Long) {
        val dDayEvent = dDayRepository.findById(id).orElseThrow()
        authenticationCheck(dDayEvent, loginMember, operation = "delete")
        dDayRepository.delete(dDayEvent)
        log.auditEventAfterCommit("dday.deleted", loginMember.toAuditActor(),
            target = mapOf("type" to "DDayEvent", "id" to id, "ownerId" to loginMember.id))
    }

    private fun authenticationCheck(
        dDayEvent: DDayEvent,
        loginMember: LoginMember?,
        operation: String,
    ) {
        if (dDayEvent.member.id != loginMember?.id) {
            log.warn(
                "D-day access denied {}",
                auditContext(
                    mapOf(
                        "actor" to loginMember?.toAuditActor(),
                        "target" to mapOf(
                            "type" to "d_day_event",
                            "id" to dDayEvent.id,
                            "ownerId" to dDayEvent.member.id,
                            "ownerName" to dDayEvent.member.name,
                            "isPrivate" to dDayEvent.isPrivate,
                        ),
                        "operation" to operation,
                    )
                ),
            )
            throw AuthException("dday.access.forbidden")
        }
    }

    private fun validatePublicTitle(dDaySaveDto: DDaySaveDto) {
        if (!dDaySaveDto.isPrivate) {
            publicContentService.validateContent(dDaySaveDto.title)
        }
    }

}
