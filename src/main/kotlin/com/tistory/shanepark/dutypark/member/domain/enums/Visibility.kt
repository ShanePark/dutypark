package com.tistory.shanepark.dutypark.member.domain.enums

enum class Visibility {
    PUBLIC,
    FRIENDS,
    FAMILY,
    PRIVATE;

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
