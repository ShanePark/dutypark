package com.tistory.shanepark.dutypark.attachment.exception

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

abstract class AttachmentException(
    message: String,
    cause: Throwable? = null
) : DutyparkException(message, cause)

class AttachmentExtensionBlockedException(
    val filename: String,
    val extension: String
) : AttachmentException("File extension '$extension' is blocked (filename: $filename)") {
    override val errorCode: Int = 400
}

class AttachmentTooLargeException(
    val filename: String,
    val size: Long,
    val maxSize: Long
) : AttachmentException("File size $size bytes exceeds maximum allowed size $maxSize bytes (filename: $filename)") {
    override val errorCode: Int = 413
}
