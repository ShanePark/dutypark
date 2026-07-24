package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

object ScheduleTimeIndicator {
    private val pattern = Regex(
        """[0-9]|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|정오|자정"""
    )

    fun existsIn(content: String): Boolean {
        return pattern.containsMatchIn(content)
    }
}
