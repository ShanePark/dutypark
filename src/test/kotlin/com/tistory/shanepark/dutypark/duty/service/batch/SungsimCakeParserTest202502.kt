package com.tistory.shanepark.dutypark.duty.service.batch

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.exceptions.YearMonthNotMatchException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.YearMonth
import kotlin.io.path.Path
import kotlin.io.path.inputStream

class SungsimCakeParserTest202502 {
    private val febFilePath = "src/test/resources/duty-batch/sungsim-cake/12028_2_25년도2월휴무.xlsx"
    private val feb2025 = YearMonth.of(2025, 2)
    private val mar2025 = YearMonth.of(2025, 3)
    private val result = SungsimCakeParser().parseDayOff(feb2025, Path(febFilePath).inputStream())

    @Test
    fun `startDate and endDate`() {
        assertThat(result.startDate).isEqualTo(feb2025.atDay(2))
        assertThat(result.endDate).isEqualTo(mar2025.atDay(8))
    }

    @Test
    fun `names of result`() {
        assertThat(result.getNames()).containsExactlyInAnyOrder(
            "레오", "맥스", "노아", "루나", "제이",
            "자라", "리오", "니아", "벡스", "에이든",
            "카이", "주드", "테오", "다샤", "미오",
            "제이크", "엘라", "코비", "타이", "노엘",
            "루크", "켄지", "소니", "니키", "코라",
            "동현", "제시", "드루", "로이", "사라",
            "테라", "엘리", "리키", "벨라", "로건", "에이미"
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
    fun `year-month and xlsx not match`() {
        for (i in 1L..6L) {
            assertThrows<YearMonthNotMatchException> {
                SungsimCakeParser().parseDayOff(
                    feb2025.plusMonths(i),
                    Path(febFilePath).inputStream()
                )
            }
            assertThrows<YearMonthNotMatchException> {
                SungsimCakeParser().parseDayOff(
                    feb2025.minusMonths(i),
                    Path(febFilePath).inputStream()
                )
            }
        }
    }

    @Test
    fun `leo resut`() {
        assertThat(result.getOffDays("레오")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(3),
            feb2025.atDay(9),
            feb2025.atDay(12),
            feb2025.atDay(18),
            feb2025.atDay(19),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `max result`() {
        assertThat(result.getOffDays("맥스")).containsExactly(
            feb2025.atDay(6),
            feb2025.atDay(7),
            feb2025.atDay(10),
            feb2025.atDay(11),
            feb2025.atDay(18),
            feb2025.atDay(19),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `noa result`() {
        assertThat(result.getOffDays("노아")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(6),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(14),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `luna result`() {
        assertThat(result.getOffDays("루나")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(9),
            feb2025.atDay(12),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(2),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `jay result`() {
        assertThat(result.getOffDays("제이")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(6),
            feb2025.atDay(10),
            feb2025.atDay(11),
            feb2025.atDay(16),
            feb2025.atDay(20),
            feb2025.atDay(21),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(5),
            mar2025.atDay(8),
        )
    }

    @Test
    fun `jara result`() {
        assertThat(result.getOffDays("자라")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(9),
            feb2025.atDay(12),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `rio result`() {
        assertThat(result.getOffDays("리오")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(9),
            feb2025.atDay(12),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(23),
            feb2025.atDay(24),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `nia result`() {
        assertThat(result.getOffDays("니아")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(6),
            feb2025.atDay(10),
            feb2025.atDay(11),
            feb2025.atDay(17),
            feb2025.atDay(20),
            feb2025.atDay(27),
            feb2025.atDay(28),
        )
    }

    @Test
    fun `beks result`() {
        assertThat(result.getOffDays("벡스")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(3),
            feb2025.atDay(9),
            feb2025.atDay(13),
            feb2025.atDay(16),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(3),
            mar2025.atDay(4),
        )
    }

    @Test
    fun `aiden result`() {
        assertThat(result.getOffDays("에이든")).containsExactly(
            feb2025.atDay(6),
            feb2025.atDay(7),
            feb2025.atDay(10),
            feb2025.atDay(13),
            feb2025.atDay(16),
            feb2025.atDay(20),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `kai result`() {
        assertThat(result.getOffDays("카이")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(15),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(4),
            mar2025.atDay(7),
        )
    }

    @Test
    fun `jude result`() {
        assertThat(result.getOffDays("주드")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(9),
            feb2025.atDay(10),
            feb2025.atDay(16),
            feb2025.atDay(25),
            feb2025.atDay(27),
            mar2025.atDay(5),
            mar2025.atDay(8),
        )
    }

    @Test
    fun `teo result`() {
        assertThat(result.getOffDays("테오")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(18),
            feb2025.atDay(19),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `dasha result`() {
        assertThat(result.getOffDays("다샤")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(10),
            feb2025.atDay(15),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(3),
            mar2025.atDay(4),
        )
    }

    @Test
    fun `mio result`() {
        assertThat(result.getOffDays("미오")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(9),
            feb2025.atDay(12),
            feb2025.atDay(13),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(4),
            mar2025.atDay(7),
        )
    }

    @Test
    fun `jake result`() {
        assertThat(result.getOffDays("제이크")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(10),
            feb2025.atDay(11),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `ella result`() {
        assertThat(result.getOffDays("엘라")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(10),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `cobi result`() {
        assertThat(result.getOffDays("코비")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(10),
            feb2025.atDay(14),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `tai result`() {
        assertThat(result.getOffDays("타이")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(9),
            feb2025.atDay(13),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(20),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `noel result`() {
        assertThat(result.getOffDays("노엘")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(7),
            feb2025.atDay(9),
            feb2025.atDay(13),
            feb2025.atDay(17),
            feb2025.atDay(22),
            feb2025.atDay(28),
            mar2025.atDay(1),
            mar2025.atDay(6),
            mar2025.atDay(7),
        )
    }

    @Test
    fun `luke result`() {
        assertThat(result.getOffDays("루크")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(6),
            feb2025.atDay(10),
            feb2025.atDay(13),
            feb2025.atDay(17),
            feb2025.atDay(20),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `kenzi result`() {
        assertThat(result.getOffDays("켄지")).containsExactly(
            feb2025.atDay(6),
            feb2025.atDay(8),
            feb2025.atDay(9),
            feb2025.atDay(14),
            feb2025.atDay(18),
            feb2025.atDay(22),
            feb2025.atDay(23),
            feb2025.atDay(28),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `sonny result`() {
        assertThat(result.getOffDays("소니")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(20),
            feb2025.atDay(21),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(2),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `niki result`() {
        assertThat(result.getOffDays("니키")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(6),
            feb2025.atDay(10),
            feb2025.atDay(13),
            feb2025.atDay(19),
            feb2025.atDay(22),
            feb2025.atDay(23),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `cora result`() {
        assertThat(result.getOffDays("코라")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(17),
            feb2025.atDay(18),
            feb2025.atDay(23),
            feb2025.atDay(27),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `jen result`() {
        assertThat(result.getOffDays("동현")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(18),
            feb2025.atDay(19),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `jessi result`() {
        assertThat(result.getOffDays("제시")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(8),
            feb2025.atDay(9),
            feb2025.atDay(11),
            feb2025.atDay(17),
            feb2025.atDay(20),
            feb2025.atDay(23),
            feb2025.atDay(27),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `dru result`() {
        assertThat(result.getOffDays("드루")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(10),
            feb2025.atDay(13),
            feb2025.atDay(19),
            feb2025.atDay(22),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `roy result`() {
        assertThat(result.getOffDays("로이")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(12),
            feb2025.atDay(13),
            feb2025.atDay(17),
            feb2025.atDay(20),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `sara result`() {
        assertThat(result.getOffDays("사라")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(9),
            feb2025.atDay(10),
            feb2025.atDay(19),
            feb2025.atDay(20),
            feb2025.atDay(24),
            feb2025.atDay(25),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

    @Test
    fun `tera result`() {
        assertThat(result.getOffDays("테라")).containsExactly(
            feb2025.atDay(6),
            feb2025.atDay(7),
            feb2025.atDay(10),
            feb2025.atDay(15),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(24),
            feb2025.atDay(27),
            mar2025.atDay(2),
            mar2025.atDay(7),
        )
    }

    @Test
    fun `eli result`() {
        assertThat(result.getOffDays("엘리")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(17),
            feb2025.atDay(21),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(2),
            mar2025.atDay(8),
        )
    }

    @Test
    fun `riki result`() {
        assertThat(result.getOffDays("리키")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(8),
            feb2025.atDay(12),
            feb2025.atDay(14),
            feb2025.atDay(18),
            feb2025.atDay(21),
            feb2025.atDay(23),
            feb2025.atDay(26),
            mar2025.atDay(2),
            mar2025.atDay(8),
        )
    }

    @Test
    fun `bella result`() {
        assertThat(result.getOffDays("벨라")).containsExactly(
            feb2025.atDay(2),
            feb2025.atDay(6),
            feb2025.atDay(10),
            feb2025.atDay(13),
            feb2025.atDay(19),
            feb2025.atDay(20),
            feb2025.atDay(25),
            feb2025.atDay(26),
            mar2025.atDay(4),
            mar2025.atDay(5),
        )
    }

    @Test
    fun `logan result`() {
        assertThat(result.getOffDays("로건")).containsExactly(
            feb2025.atDay(4),
            feb2025.atDay(5),
            feb2025.atDay(11),
            feb2025.atDay(15),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(24),
            mar2025.atDay(1),
            mar2025.atDay(7),
            mar2025.atDay(8),
        )
    }

    @Test
    fun `amy result`() {
        assertThat(result.getOffDays("에이미")).containsExactly(
            feb2025.atDay(3),
            feb2025.atDay(4),
            feb2025.atDay(8),
            feb2025.atDay(11),
            feb2025.atDay(12),
            feb2025.atDay(16),
            feb2025.atDay(19),
            feb2025.atDay(23),
            feb2025.atDay(24),
            mar2025.atDay(3),
            mar2025.atDay(6),
        )
    }

}
