package com.tistory.shanepark.dutypark.report.domain.enums

enum class ReportStatus {
    OPEN,
    RESOLVED,
    DISMISSED,

    /** 신고자 본인이 철회한 건. 관리자가 판단해 기각한 [DISMISSED] 와 달리 심사 자체가 없었다. */
    CANCELED
}
