package com.tistory.shanepark.dutypark.member.exception

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class SocialAccountUnlinkException(
    message: String,
    override val errorCode: Int,
) : DutyparkException(message, null)
