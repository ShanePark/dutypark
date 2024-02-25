package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.FriendsInfoDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Page
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

    @GetMapping("/info")
    fun friendInfo(
        @Login loginMember: LoginMember
    ): FriendsInfoDto {
        return friendService.getMyFriendInfo(loginMember)
    }

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
    ): Page<MemberDto> {
        return friendService.searchPossibleFriends(loginMember, keyword, page)
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

    @DeleteMapping("{deleteMemberId}")
    fun unfriend(
        @Login loginMember: LoginMember,
        @PathVariable deleteMemberId: Long
    ) {
        friendService.unfriend(loginMember, deleteMemberId)
    }

}
