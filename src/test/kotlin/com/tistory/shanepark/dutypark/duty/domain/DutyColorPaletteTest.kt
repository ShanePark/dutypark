package com.tistory.shanepark.dutypark.duty.domain

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import java.nio.file.Path
import kotlin.io.path.readText

class DutyColorPaletteTest {
    @Test
    fun `backend web and iOS share the same ordered palette`() {
        val expected = listOf(
            "#ECC2C9", "#F6BC7A", "#F6D365", "#D8BF9B", "#C8DD70", "#A6D99B",
            "#8FDCBD", "#9DDBDE", "#D1B8EC", "#E9AEE9", "#CCC8BD",
        )
        val hex = Regex("#[0-9A-F]{6}")
        val web = Path.of("frontend/src/utils/dutyTypePalette.ts").readText()
            .substringAfter("export const dutyTypePalette = [").substringBefore("] as const")
        val iOS = Path.of("ios/DutyparkWidgetShared/DutyTypeColorPalette.swift").readText()
            .substringAfter("static let options = [").substringBefore("]")

        assertThat(DutyColorPalette.colors).containsExactlyElementsOf(expected)
        assertThat(hex.findAll(web).map { it.value }.toList()).containsExactlyElementsOf(expected)
        assertThat(hex.findAll(iOS).map { it.value }.toList()).containsExactlyElementsOf(expected)
        assertThat(DutyColorPalette.DEFAULT_COLOR).isEqualTo("#F6D365")
        assertThat(DutyColorPalette.DEFAULT_OFF_COLOR).isEqualTo("#ECC2C9")
    }

    @Test
    fun `palette colors can be newly assigned with either hex casing`() {
        DutyColorPalette.colors.forEach { color ->
            assertDoesNotThrow { DutyColorPalette.validate(color) }
            assertDoesNotThrow { DutyColorPalette.validate(color.lowercase(), "#abcdef") }
        }
    }

    @Test
    fun `custom hex colors can be newly assigned or retained with either casing`() {
        assertDoesNotThrow { DutyColorPalette.validate("#ABCDEF", "#abcdef") }
        assertDoesNotThrow { DutyColorPalette.validate("#abcdef") }
        assertDoesNotThrow { DutyColorPalette.validate("#abcdef", "#123456") }
    }

    @ParameterizedTest
    @ValueSource(strings = ["#123", "#1234567", "123456", "#GG1234", "red"])
    fun `new custom colors still require six digit hex format`(color: String) {
        val exception = assertThrows<IllegalArgumentException> { DutyColorPalette.validate(color) }
        assertThat(exception.message).isEqualTo("dutyType.color.invalid")
    }

    @Test
    fun `new team default duty uses a distinct palette color`() {
        assertThat(Team("new").defaultDutyColor).isEqualTo(DutyColorPalette.DEFAULT_OFF_COLOR)
        assertThat(DutyColorPalette.DEFAULT_OFF_COLOR).isNotEqualTo(DutyColorPalette.DEFAULT_COLOR)
        assertDoesNotThrow { DutyColorPalette.validate(DutyColorPalette.DEFAULT_OFF_COLOR) }
    }
}
