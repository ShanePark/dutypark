package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.FriendDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.dto.UpdateProfilePhotoRequest
import com.tistory.shanepark.dutypark.member.domain.dto.VisibilityUpdateRequest
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.member.service.ProfilePhotoService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.core.io.Resource
import org.springframework.core.io.UrlResource
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/members")
class MemberController(
    private val memberService: MemberService,
    private val friendService: FriendService,
    private val profilePhotoService: ProfilePhotoService,
    private val pathResolver: StoragePathResolver,
) {

    @GetMapping("/me")
    fun getMyInfo(
        @Login loginMember: LoginMember,
    ): MemberDto {
        return memberService.findById(loginMember.id)
    }

    @PutMapping("{memberId}/visibility")
    fun updateCalendarVisibility(
        @Login loginMember: LoginMember,
        @PathVariable memberId: Long,
        @RequestBody visibilityUpdateRequest: VisibilityUpdateRequest,
    ) {
        if (memberId != loginMember.id) {
            throw IllegalArgumentException("You can't update other member's visibility")
        }
        val visibility = visibilityUpdateRequest.visibility
        memberService.updateCalendarVisibility(loginMember, visibility)
    }

    @PostMapping("/manager/{managerId}")
    fun assignManager(
        @Login loginMember: LoginMember,
        @PathVariable managerId: Long,
    ) {
        memberService.assignManager(managerId = managerId, managedId = loginMember.id)
    }

    @DeleteMapping("/manager/{managerId}")
    fun unassignManager(
        @Login loginMember: LoginMember,
        @PathVariable managerId: Long,
    ) {
        memberService.unassignManager(managerId = managerId, managedId = loginMember.id)
    }

    @GetMapping("/family")
    fun getFamilyMembers(
        @Login loginMember: LoginMember,
    ): List<FriendDto> {
        return friendService.findAllFamilyMembers(loginMember.id)
    }

    @GetMapping("/managers")
    fun getManagers(
        @Login loginMember: LoginMember,
    ): List<MemberDto> {
        return memberService.findAllManagers(loginMember)
    }

    @GetMapping("/managed")
    fun getManagedMembers(
        @Login loginMember: LoginMember,
    ): List<MemberDto> {
        return memberService.findManagedMembers(loginMember)
    }

    @GetMapping("/{memberId}/canManage")
    fun amIManager(
        @Login(required = false) loginMember: LoginMember?,
        @PathVariable memberId: Long,
    ): Boolean {
        if (loginMember == null) {
            return false
        }
        return memberService.isManager(isManager = loginMember, targetMemberId = memberId)
    }

    @GetMapping("/{memberId}")
    fun getMemberById(
        @Login(required = false) loginMember: LoginMember?,
        @PathVariable memberId: Long,
    ): MemberDto {
        friendService.checkVisibility(loginMember, memberId)
        return memberService.findById(memberId)
    }

    @PutMapping("/profile-photo")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun updateProfilePhoto(
        @Login loginMember: LoginMember,
        @RequestBody request: UpdateProfilePhotoRequest,
    ) {
        profilePhotoService.setProfilePhoto(
            loginMember = loginMember,
            sessionId = request.sessionId,
            attachmentId = request.attachmentId
        )
    }

    @DeleteMapping("/profile-photo")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteProfilePhoto(
        @Login loginMember: LoginMember,
    ) {
        profilePhotoService.deleteProfilePhoto(loginMember)
    }

    @GetMapping("/{memberId}/profile-photo")
    fun getProfilePhoto(
        @PathVariable memberId: Long,
    ): ResponseEntity<Resource> {
        val attachment = profilePhotoService.getProfilePhoto(memberId)
            ?: return ResponseEntity.notFound().build()

        val thumbnailFilename = attachment.thumbnailFilename
            ?: return ResponseEntity.notFound().build()

        val thumbnailPath = pathResolver.resolveThumbnailPath(
            attachment.contextType,
            attachment.contextId,
            attachment.uploadSessionId,
            thumbnailFilename
        )

        val resource = UrlResource(thumbnailPath.toUri())
        if (!resource.exists()) {
            return ResponseEntity.notFound().build()
        }

        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType(attachment.thumbnailContentType ?: "image/png"))
            .body(resource)
    }

}
