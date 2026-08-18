package com.tistory.shanepark.dutypark.member.block.controller

import com.tistory.shanepark.dutypark.member.block.domain.dto.BlockedMemberDto
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/blocks")
class BlockController(
    private val blockService: BlockService,
) {

    @GetMapping
    fun getBlockedMembers(
        @Login loginMember: LoginMember
    ): List<BlockedMemberDto> {
        return blockService.findBlockedMembers(loginMember.id)
    }

    @PostMapping("/{memberId}")
    fun block(
        @Login loginMember: LoginMember,
        @PathVariable memberId: Long
    ) {
        blockService.block(loginMember.id, memberId)
    }

    @DeleteMapping("/{memberId}")
    fun unblock(
        @Login loginMember: LoginMember,
        @PathVariable memberId: Long
    ) {
        blockService.unblock(loginMember.id, memberId)
    }

}
