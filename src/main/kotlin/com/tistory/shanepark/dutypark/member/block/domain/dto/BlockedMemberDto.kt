package com.tistory.shanepark.dutypark.member.block.domain.dto

import com.tistory.shanepark.dutypark.member.block.domain.entity.MemberBlock
import java.time.LocalDateTime

data class BlockedMemberDto(
    val id: Long,
    val name: String,
    val hasProfilePhoto: Boolean,
    val profilePhotoVersion: Long,
    val blockedAt: LocalDateTime,
)

internal fun MemberBlock.toBlockedMemberDto(): BlockedMemberDto {
    return BlockedMemberDto(
        id = blocked.id!!,
        name = blocked.name,
        hasProfilePhoto = blocked.hasProfilePhoto(),
        profilePhotoVersion = blocked.profilePhotoVersion,
        blockedAt = createdDate,
    )
}
