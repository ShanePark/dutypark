package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.FriendsInfoDto
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/friends")
class FriendController(
    private val friendService: FriendService
) {

    @GetMapping
    fun friendInfo(
        @Login loginMember: LoginMember
    ): FriendsInfoDto {
        return friendService.getMyFriendInfo(loginMember)
    }

    @DeleteMapping("{deleteMemberId}")
    fun unfriend(
        @Login loginMember: LoginMember,
        @PathVariable deleteMemberId: Long
    ) {
        friendService.unfriend(loginMember, deleteMemberId)
    }

    @PostMapping("request/send/{toMemberId}")
    fun sendFriendRequest(
        @Login loginMember: LoginMember,
        @PathVariable toMemberId: Long
    ) {
        friendService.sendFriendRequest(loginMember, toMemberId)
    }

    @PostMapping("request/cancel/{toMemberId}")
    fun cancelFriendRequest(
        @Login loginMember: LoginMember,
        @PathVariable toMemberId: Long
    ) {
        friendService.cancelFriendRequest(loginMember, toMemberId)
    }

    @PostMapping("request/accept/{fromMemberId}")
    fun acceptFriendRequest(
        @Login loginMember: LoginMember,
        @PathVariable fromMemberId: Long
    ) {
        friendService.acceptFriendRequest(loginMember, fromMemberId)
    }

    @PostMapping("request/reject/{fromMemberId}")
    fun rejectFriendRequest(
        @Login loginMember: LoginMember,
        @PathVariable fromMemberId: Long
    ) {
        friendService.rejectFriendRequest(loginMember, fromMemberId)
    }

}
