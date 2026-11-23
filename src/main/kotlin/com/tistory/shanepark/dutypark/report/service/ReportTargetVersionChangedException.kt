package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class ReportTargetVersionChangedException : DutyparkException("report.target.versionChanged", null) {
    override val errorCode: Int = 409
}
