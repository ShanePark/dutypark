package com.tistory.shanepark.dutypark.department.domain.dto

data class SimpleDepartmentDto(
    val id: Long,
    val name: String,
    val description: String?,
    val memberCount: Long,
) {

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SimpleDepartmentDto) return false

        if (id != other.id) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

}
