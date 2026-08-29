package com.tistory.shanepark.dutypark.common.slack.annotation

@Target(AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
annotation class SlackNotification(
    /** Retained for source compatibility; the aspect never serializes method arguments. */
    val includeArguments: Boolean = false,
)
