package com.tistory.shanepark.dutypark.member.exception

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class MemberSuspensionException(
    message: String,
    override val errorCode: Int = 409,
) : DutyparkException(message, null)
