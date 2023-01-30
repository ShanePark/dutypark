package com.tistory.shanepark.dutypark.member.domain.annotation

@Target(AnnotationTarget.VALUE_PARAMETER)
@Retention(AnnotationRetention.RUNTIME)
annotation class Login(
    val required: Boolean = true
)
