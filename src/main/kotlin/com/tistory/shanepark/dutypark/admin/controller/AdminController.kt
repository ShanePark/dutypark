package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.data.web.PageableDefault
import org.springframework.data.web.SortDefault
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/admin/api/")
class AdminController(
    private val refreshTokenService: RefreshTokenService,
    private val memberService: MemberService,
) {
    @GetMapping("/refresh-tokens")
    fun findAllRefreshTokens(): List<RefreshTokenDto> {
        return refreshTokenService.findAllWithMemberOrderByLastUsedDesc()
    }

    @GetMapping("/members-all")
    fun findAllMembers(): List<MemberDto> {
        return memberService.findAll()
    }

}
