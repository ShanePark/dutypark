package com.tistory.shanepark.dutypark.duty.domain

object DutyAbbreviation {
    private val firstCharacter = Regex("\\X")

    fun normalize(value: String?): String? = value?.trim()?.takeIf { it.isNotEmpty() }

    fun resolve(name: String, abbreviation: String? = null): String =
        normalize(abbreviation) ?: firstCharacter.find(name.trim())?.value.orEmpty()
}
