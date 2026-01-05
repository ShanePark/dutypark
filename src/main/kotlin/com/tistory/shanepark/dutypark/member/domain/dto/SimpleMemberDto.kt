package com.tistory.shanepark.dutypark.member.domain.dto

data class SimpleMemberDto(
    val id: Long,
    val name: String,
    val hasProfilePhoto: Boolean = false,
) {
    constructor(id: Long?, name: String, hasProfilePhoto: Boolean = false) : this(id ?: 0, name, hasProfilePhoto)
}
