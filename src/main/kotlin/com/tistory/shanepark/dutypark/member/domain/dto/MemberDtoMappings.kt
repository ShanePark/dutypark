package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member

internal fun Member.toMemberPreviewDto(): MemberPreviewDto {
    return MemberPreviewDto(
        id = id,
        name = name,
        teamId = team?.id,
        team = team?.name,
        hasProfilePhoto = hasProfilePhoto(),
        profilePhotoVersion = profilePhotoVersion,
    )
}

internal fun Member.toMemberDto(kakaoId: String? = null, naverId: String? = null): MemberDto {
    val preview = toMemberPreviewDto()
    return MemberDto(
        id = preview.id,
        name = preview.name,
        email = email,
        teamId = preview.teamId,
        team = preview.team,
        calendarVisibility = calendarVisibility,
        kakaoId = kakaoId,
        naverId = naverId,
        hasPassword = password != null,
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
    )
}

internal fun FriendRelation.toFriendDto(): FriendDto {
    val preview = friend.toMemberPreviewDto()
    return FriendDto(
        id = preview.id ?: throw IllegalStateException("Member id is null"),
        name = preview.name,
        teamId = preview.teamId,
        team = preview.team,
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
        isFamily = isFamily,
        pinOrder = pinOrder,
    )
}

internal fun FriendRequest.toFriendRequestDto(): FriendRequestDto {
    return FriendRequestDto(
        id = id ?: throw IllegalStateException("FriendRequest id is null"),
        fromMember = fromMember.toMemberPreviewDto(),
        toMember = toMember.toMemberPreviewDto(),
        status = status.name,
        createdAt = createdDate,
        requestType = requestType,
    )
}
