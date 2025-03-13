package com.tistory.shanepark.dutypark.member.domain.dto

data class SimpleMemberDto(
    val id: Long,
    val name: String,
) {
    constructor(id: Long?, name: String) : this(id ?: 0, name)
}
