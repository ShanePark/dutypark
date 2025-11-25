package com.tistory.shanepark.dutypark.security.domain.dto

data class LoginMember(
    val id: Long,
    val email: String? = null,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    var isAdmin: Boolean = false
) {
    companion object {
        const val ATTR_NAME: String = "loginMember"
    }

    override fun toString(): String {
        return "${name}(${id})"
    }


}
