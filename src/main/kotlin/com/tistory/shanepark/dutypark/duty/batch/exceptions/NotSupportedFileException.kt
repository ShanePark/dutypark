package com.tistory.shanepark.dutypark.duty.batch.exceptions

class NotSupportedFileException(supportedFile: String) : DutyBatchException(
    "지원하지 않는 파일 형식입니다. 지원하는 파일 형식: $supportedFile"
)
