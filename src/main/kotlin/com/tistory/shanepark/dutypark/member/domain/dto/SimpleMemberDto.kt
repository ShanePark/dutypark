package com.tistory.shanepark.dutypark.member.domain.dto

data class SimpleMemberDto(
    val id: Long,
    val name: String,
    val profilePhotoUrl: String? = null,
) {
    constructor(id: Long?, name: String) : this(id ?: 0, name, null)
    constructor(id: Long?, name: String, profilePhotoUrl: String?) : this(id ?: 0, name, profilePhotoUrl)
}
