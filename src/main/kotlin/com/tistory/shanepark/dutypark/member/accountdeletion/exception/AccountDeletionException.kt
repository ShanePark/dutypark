package com.tistory.shanepark.dutypark.member.accountdeletion.exception

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class AccountDeletionException(
    message: String,
    override val errorCode: Int,
) : DutyparkException(message, null)
