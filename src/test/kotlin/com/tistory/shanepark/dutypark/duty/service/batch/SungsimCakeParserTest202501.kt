package com.tistory.shanepark.dutypark.duty.service.batch

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.exceptions.YearMonthNotMatchException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.YearMonth
import kotlin.io.path.Path
import kotlin.io.path.inputStream

class SungsimCakeParserTest202501 {
    private val janFilePath = "src/test/resources/duty-batch/sungsim-cake/12013_2_25년도1월휴무.xlsx"
    private val jan2025 = YearMonth.of(2025, 1)
    private val feb2025 = YearMonth.of(2025, 2)
    private val result = SungsimCakeParser().parseDayOff(jan2025, Path(janFilePath).inputStream())

    @Test
    fun `startDate and endDate`() {
        assertThat(result.startDate).isEqualTo(jan2025.atDay(5))
        assertThat(result.endDate).isEqualTo(feb2025.atDay(1))
    }

    @Test
    fun `names of result`() {
        assertThat(result.getNames()).containsExactlyInAnyOrder(
            "레오", "맥스", "노아", "루나", "제이",
            "자라", "리오", "니아", "벡스", "에이든",
            "카이", "주드", "테오", "아라", "다샤",
            "미오", "제이크", "엘라", "코비", "타이",
            "노엘", "오스카", "루크", "켄지", "소니",
            "다헤", "니키", "지아", "로건", "오에미",
            "휴고", "코라", "동현", "제시", "드루",
            "로이", "사라", "테라", "엘리", "리키",
            "비비", "벨라"
        )
    }

    @Test
    fun `assert each name has exact workingDays and offDays without omission`() {
        for (name in result.getNames()) {
            val workDays = result.getWorkDays(name)
            val offDays = result.getOffDays(name)
            assertThat(workDays.size + offDays.size).isEqualTo(
                result.startDate.datesUntil(result.endDate).count().plus(1)
            )
            assertThat(workDays).noneMatch { it in offDays }
        }
    }

    @Test
    fun `in case of year-month and xlsx not match it throws YearMonthNotMatchException`() {
        for (i in 1L..6L) {
            assertThrows<YearMonthNotMatchException> {
                SungsimCakeParser().parseDayOff(
                    jan2025.plusMonths(i),
                    Path(janFilePath).inputStream()
                )
            }
            assertThrows<YearMonthNotMatchException> {
                SungsimCakeParser().parseDayOff(
                    jan2025.minusMonths(i),
                    Path(janFilePath).inputStream()
                )
            }
        }

        // 2025-01 and 2025-10 calendar looks same so can't distinguish. any idea to distinguish?
        SungsimCakeParser().parseDayOff(
            YearMonth.of(2025, 10),
            Path(janFilePath).inputStream()
        )
    }

    @Test
    fun `leo result`() {
        assertThat(result.getOffDays("레오")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `max result`() {
        assertThat(result.getOffDays("맥스")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(8),
            jan2025.atDay(12),
            jan2025.atDay(17),
            jan2025.atDay(19),
            jan2025.atDay(20),
            jan2025.atDay(24),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `noah result`() {
        assertThat(result.getOffDays("노아")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(10),
            jan2025.atDay(13),
            jan2025.atDay(14),
            jan2025.atDay(21),
            jan2025.atDay(23),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `luna result`() {
        assertThat(result.getOffDays("루나")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(8),
            jan2025.atDay(12),
            jan2025.atDay(15),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(28),
            jan2025.atDay(29),
        )
    }

    @Test
    fun `jay result`() {
        assertThat(result.getOffDays("제이")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(6),
            jan2025.atDay(12),
            jan2025.atDay(16),
            jan2025.atDay(19),
            jan2025.atDay(25),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `jara result`() {
        assertThat(result.getOffDays("자라")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(9),
            jan2025.atDay(13),
            jan2025.atDay(14),
            jan2025.atDay(16),
            jan2025.atDay(21),
            jan2025.atDay(22),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `rio result`() {
        assertThat(result.getOffDays("리오")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(6),
            jan2025.atDay(9),
            jan2025.atDay(12),
            jan2025.atDay(13),
            jan2025.atDay(19),
            jan2025.atDay(23),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `nia result`() {
        assertThat(result.getOffDays("니아")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(8),
            jan2025.atDay(14),
            jan2025.atDay(18),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(24),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `beks result`() {
        assertThat(result.getOffDays("벡스")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(9),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `aiden result`() {
        assertThat(result.getOffDays("에이든")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(9),
            jan2025.atDay(10),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(20),
            jan2025.atDay(23),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `kai result`() {
        assertThat(result.getOffDays("카이")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(6),
            jan2025.atDay(12),
            jan2025.atDay(17),
            jan2025.atDay(23),
            jan2025.atDay(24),
            jan2025.atDay(30),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `jude result`() {
        assertThat(result.getOffDays("주드")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(13),
            jan2025.atDay(14),
            jan2025.atDay(20),
            jan2025.atDay(22),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `teo result`() {
        assertThat(result.getOffDays("테오")).containsExactly(
            jan2025.atDay(5),
            jan2025.atDay(8),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(25),
            jan2025.atDay(28),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `ara result`() {
        assertThat(result.getOffDays("아라")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(12),
            jan2025.atDay(13),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(25),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `dasha result`() {
        assertThat(result.getOffDays("다샤")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(15),
            jan2025.atDay(16),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(22),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `mio result`() {
        assertThat(result.getOffDays("미오")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `jake result`() {
        assertThat(result.getOffDays("제이크")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(12),
            jan2025.atDay(13),
            jan2025.atDay(18),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `ella result`() {
        assertThat(result.getOffDays("엘라")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(11),
            jan2025.atDay(12),
            jan2025.atDay(13),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(26),
            jan2025.atDay(27),
        )
    }

    @Test
    fun `coby result`() {
        assertThat(result.getOffDays("코비")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(10),
            jan2025.atDay(12),
            jan2025.atDay(16),
            jan2025.atDay(22),
            jan2025.atDay(23),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `tai result`() {
        assertThat(result.getOffDays("타이")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `noel result`() {
        assertThat(result.getOffDays("노엘")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(9),
            jan2025.atDay(13),
            jan2025.atDay(18),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(26),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `oscar result`() {
        assertThat(result.getOffDays("오스카")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(11),
            jan2025.atDay(14),
            jan2025.atDay(17),
            jan2025.atDay(21),
            jan2025.atDay(25),
            jan2025.atDay(27),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `luke result`() {
        assertThat(result.getOffDays("루크")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(7),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(21),
            jan2025.atDay(25),
            jan2025.atDay(29),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `kenzi result`() {
        assertThat(result.getOffDays("켄지")).containsExactly(
            jan2025.atDay(6),
            jan2025.atDay(10),
            jan2025.atDay(12),
            jan2025.atDay(15),
            jan2025.atDay(21),
            jan2025.atDay(25),
            jan2025.atDay(28),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `sonny result`() {
        assertThat(result.getOffDays("소니")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(19),
            jan2025.atDay(24),
            jan2025.atDay(26),
        )
    }

    @Test
    fun `dahe result`() {
        assertThat(result.getOffDays("다헤")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
        )
    }

    @Test
    fun `niki result`() {
        assertThat(result.getOffDays("니키")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `gia result`() {
        assertThat(result.getOffDays("지아")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(18),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `logan result`() {
        assertThat(result.getOffDays("로건")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(9),
            jan2025.atDay(12),
            jan2025.atDay(17),
            jan2025.atDay(20),
            jan2025.atDay(23),
            jan2025.atDay(28),
            jan2025.atDay(29),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `oemi result`() {
        assertThat(result.getOffDays("오에미")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(22),
            jan2025.atDay(23),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `hugo result`() {
        assertThat(result.getOffDays("휴고")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(11),
            jan2025.atDay(13),
            jan2025.atDay(18),
            jan2025.atDay(20),
            jan2025.atDay(24),
            jan2025.atDay(27),
            feb2025.atDay(1),
        )
    }

    @Test
    fun `cora result`() {
        assertThat(result.getOffDays("코라")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(13),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(26),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `jenny result`() {
        assertThat(result.getOffDays("동현")).containsExactly(
            jan2025.atDay(7),
            jan2025.atDay(8),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(20),
            jan2025.atDay(23),
            jan2025.atDay(28),
            jan2025.atDay(29),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `jessie result`() {
        assertThat(result.getOffDays("제시")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(11),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(23),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `drew result`() {
        assertThat(result.getOffDays("드루")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(9),
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(23),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `roy result`() {
        assertThat(result.getOffDays("로이")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(9),
            jan2025.atDay(13),
            jan2025.atDay(14),
            jan2025.atDay(22),
            jan2025.atDay(23),
            jan2025.atDay(26),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `sara result`() {
        assertThat(result.getOffDays("사라")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(9),
            jan2025.atDay(11),
            jan2025.atDay(12),
            jan2025.atDay(17),
            jan2025.atDay(21),
            jan2025.atDay(22),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `tera result`() {
        assertThat(result.getOffDays("테라")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(11),
            jan2025.atDay(15),
            jan2025.atDay(16),
            jan2025.atDay(22),
            jan2025.atDay(23),
            jan2025.atDay(29),
            jan2025.atDay(30),
        )
    }

    @Test
    fun `eli result`() {
        assertThat(result.getOffDays("엘리")).containsExactly(
            jan2025.atDay(8),
            jan2025.atDay(9),
            jan2025.atDay(13),
            jan2025.atDay(16),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(27),
            jan2025.atDay(31),
        )
    }

    @Test
    fun `ricky result`() {
        assertThat(result.getOffDays("리키")).containsExactly(
            jan2025.atDay(9),
            jan2025.atDay(10),
            jan2025.atDay(12),
            jan2025.atDay(18),
            jan2025.atDay(19),
            jan2025.atDay(22),
            jan2025.atDay(26),
            jan2025.atDay(27),
        )
    }

    @Test
    fun `vivi result`() {
        assertThat(result.getOffDays("비비")).containsExactly(
            jan2025.atDay(9),
            jan2025.atDay(10),
            jan2025.atDay(15),
            jan2025.atDay(16),
            jan2025.atDay(19),
            jan2025.atDay(24),
            jan2025.atDay(26),
            jan2025.atDay(27),
        )
    }

    @Test
    fun `bella result`() {
        assertThat(result.getOffDays("벨라")).containsExactly(
            jan2025.atDay(14),
            jan2025.atDay(15),
            jan2025.atDay(18),
            jan2025.atDay(20),
            jan2025.atDay(21),
            jan2025.atDay(30),
        )
    }

}
