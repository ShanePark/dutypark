package com.tistory.shanepark.dutypark.member.domain.enums

enum class Visibility(
    val label: String
) {
    PUBLIC("공개"),
    FRIENDS("친구공개"),
    FAMILY("가족공개"),
    PRIVATE("비공개");

    companion object {
        fun publicOnly(): Set<Visibility> {
            return setOf(PUBLIC)
        }

        fun friends(): Set<Visibility> {
            return setOf(PUBLIC, FRIENDS)
        }

        fun family(): Set<Visibility> {
            return setOf(PUBLIC, FRIENDS, FAMILY)
        }

        fun all(): Set<Visibility> {
            return Visibility.entries.toSet()
        }
    }

}
