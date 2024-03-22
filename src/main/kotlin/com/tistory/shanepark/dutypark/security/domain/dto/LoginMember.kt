package com.tistory.shanepark.dutypark.security.domain.dto

data class LoginMember(
    val id: Long,
    val email: String?,
    val name: String,
    val departmentId: Long?,
    val department: String?,
    @Transient
    val jwt: String,
    var isAdmin: Boolean
) {
    companion object {
        const val attrName: String = "loginMember"
    }

}
