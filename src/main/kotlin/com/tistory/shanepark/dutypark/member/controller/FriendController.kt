package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.data.web.PageableDefault
import org.springframework.data.web.SortDefault
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/friends")
class FriendController(
    private val friendService: FriendService
) {
    @GetMapping
    fun getFriends(
        @Login loginMember: LoginMember
    ): List<MemberDto> {
        return friendService.findAllFriends(loginMember)
    }

    @GetMapping("search")
    fun searchPossibleFriends(
        @Login loginMember: LoginMember,
        @PageableDefault(page = 0, size = 10)
        @SortDefault(sort = ["name"], direction = Sort.Direction.ASC)
        page: Pageable,
        @RequestParam(required = false, defaultValue = "") keyword: String,
    ): PageResponse<MemberDto> {
        return PageResponse(friendService.searchPossibleFriends(loginMember, keyword, page))
    }

    @PostMapping("request/send/{toMemberId}")
    fun sendFriendRequest(
        @Login loginMember: LoginMember,
        @PathVariable toMemberId: Long
    ) {
        friendService.sendFriendRequest(loginMember, toMemberId)
    }

    @DeleteMapping("request/cancel/{toMemberId}")
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

    @PutMapping("/family/{toMemberId}")
    fun sendFamilyRequest(@Login loginMember: LoginMember, @PathVariable toMemberId: Long) {
        friendService.sendFamilyRequest(loginMember, toMemberId)
    }

    @DeleteMapping("{deleteMemberId}")
    fun unfriend(
        @Login loginMember: LoginMember,
        @PathVariable deleteMemberId: Long
    ) {
        friendService.unfriend(loginMember, deleteMemberId)
    }

    @PatchMapping("/pin/{friendId}")
    fun pinFriend(
        @Login loginMember: LoginMember,
        @PathVariable friendId: Long,
    ) {
        friendService.pinFriend(loginMember, friendId)
    }

    @PatchMapping("/unpin/{friendId}")
    fun unpinFriend(
        @Login loginMember: LoginMember,
        @PathVariable friendId: Long,
    ) {
        friendService.unpinFriend(loginMember, friendId)
    }

    @PatchMapping("/pin/order")
    fun updateFriendsPin(
        @Login loginMember: LoginMember,
        @RequestBody order: List<Long>
    ) {
        friendService.updateFriendsPin(loginMember, order)
    }

}
