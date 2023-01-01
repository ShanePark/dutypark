package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.security.domain.entity.LoginSession

class LoginSessionResponse(
    val accessToken: String
) {
    constructor(session: LoginSession) : this(session.accessToken)

}
