package com.tistory.shanepark.dutypark.member.domain.enums

enum class Visibility(
    val label: String
) {
    PUBLIC("공개"),
    FRIENDS("친구공개"),
    FAMILY("가족공개"),
    PRIVATE("비공개")
}
