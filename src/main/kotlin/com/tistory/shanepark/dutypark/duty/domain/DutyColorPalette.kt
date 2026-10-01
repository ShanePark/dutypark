package com.tistory.shanepark.dutypark.duty.domain

object DutyColorPalette {
    const val DEFAULT_COLOR = "#F6D365"
    const val DEFAULT_OFF_COLOR = "#ECC2C9"

    val colors = listOf(
        DEFAULT_OFF_COLOR,
        "#F6BC7A",
        DEFAULT_COLOR,
        "#D8BF9B",
        "#C8DD70",
        "#A6D99B",
        "#8FDCBD",
        "#9DDBDE",
        "#D1B8EC",
        "#E9AEE9",
        "#CCC8BD",
    )

    fun validate(color: String, currentColor: String? = null) {
        // Existing colors remain usable when only other duty fields are edited.
        require(color.equals(currentColor, ignoreCase = true) || HEX_COLOR.matches(color)) {
            "dutyType.color.invalid"
        }
    }

    private val HEX_COLOR = Regex("^#[0-9a-fA-F]{6}$")
}
