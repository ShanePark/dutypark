package com.tistory.shanepark.dutypark.attachment.exception

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

abstract class AttachmentException(
    message: String,
    cause: Throwable? = null
) : DutyparkException(message, cause)

class AttachmentExtensionBlockedException(
    val filename: String,
    val extension: String
) : AttachmentException("attachment.extension.blocked") {
    override val errorCode: Int = 400
}

class AttachmentTooLargeException(
    val filename: String,
    val size: Long,
    val maxSize: Long
) : AttachmentException("attachment.size.exceeded") {
    override val errorCode: Int = 413
}
