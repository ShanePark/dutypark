package com.tistory.shanepark.dutypark.duty.domain

object DutyAbbreviation {
    private val firstCharacter = Regex("\\X")
    private val validOverride = Regex("^[A-Za-z가-힣]{1,3}$")

    /**
     * Normalizes a stored override for display. Invalid legacy values are ignored so the
     * automatic name-based abbreviation remains a safe fallback until the data is repaired.
     */
    fun normalize(value: String?): String? = value?.trim()
        ?.takeIf { it.isNotEmpty() && validOverride.matches(it) }

    /**
     * Normalizes a client-provided override and rejects anything that cannot be stored.
     * Whitespace-only values deliberately reset the override to automatic mode.
     */
    fun normalizeAndValidate(value: String?): String? {
        val trimmed = value?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        require(validOverride.matches(trimmed)) { INVALID_CODE }
        return trimmed
    }

    fun resolve(name: String, abbreviation: String? = null): String =
        normalize(abbreviation) ?: firstCharacter.find(name.trim())?.value.orEmpty()

    private const val INVALID_CODE = "dutyType.abbreviation.invalid"
}
