package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.VisibilityUpdateRequest
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/members")
class MemberController(
    private val memberService: MemberService
) {

    @PutMapping("{memberId}/visibility")
    fun updateCalendarVisibility(
        @PathVariable memberId: Long,
        @RequestBody visibilityUpdateRequest: VisibilityUpdateRequest,
        @Login loginMember: LoginMember
    ) {
        if (memberId != loginMember.id) {
            throw IllegalArgumentException("You can't update other member's visibility")
        }
        val visibility = visibilityUpdateRequest.visibility
        memberService.updateCalendarVisibility(loginMember, visibility)
    }

}
