package com.tistory.shanepark.dutypark.team.domain.dto

data class SimpleTeamDto(
    val id: Long,
    val name: String,
    val description: String?,
    val memberCount: Long,
) {

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SimpleTeamDto) return false

        if (id != other.id) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

}
