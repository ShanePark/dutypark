package com.tistory.shanepark.dutypark.duty.service.batch

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.YearMonth
import kotlin.io.path.Path
import kotlin.io.path.inputStream

class SungsimCakeParserTest {

    @Test
    fun `Parse 2501xlsx`() {
        // When
        val result = SungsimCakeParser().parseDayOff(
            YearMonth.of(2025, 1),
            Path("src/test/resources/duty-batch/sungsim-cake/12013_2_25년도1월휴무.xlsx").inputStream()
        )

        assertThat(result.startDate).isEqualTo(YearMonth.of(2025, 1).atDay(5))
        assertThat(result.endDate).isEqualTo(YearMonth.of(2025, 2).atDay(1))

        assertThat(result.getNames()).containsExactlyInAnyOrder(
            "레오",
            "맥스",
            "노아",
            "루나",
            "제이",
            "자라",
            "리오",
            "니아",
            "벡스",
            "에이든",
            "카이",
            "주드",
            "테오",
            "아라",
            "다샤",
            "미오",
            "제이크",
            "엘라",
            "코비",
            "타이",
            "노엘",
            "오스카",
            "루크",
            "켄지",
            "소니",
            "다헤",
            "니키",
            "지아",
            "로건",
            "오에미",
            "휴고",
            "코라",
            "동현",
            "제시",
            "드루",
            "로이",
            "사라",
            "테라",
            "엘리",
            "리키",
            "비비",
            "벨라"
        )
        assertThat(result.getOffDays("동현")).hasSize(9)
        assertThat(result.getOffDays("동현")).containsExactly(
            YearMonth.of(2025, 1).atDay(7),
            YearMonth.of(2025, 1).atDay(8),
            YearMonth.of(2025, 1).atDay(14),
            YearMonth.of(2025, 1).atDay(15),
            YearMonth.of(2025, 1).atDay(20),
            YearMonth.of(2025, 1).atDay(23),
            YearMonth.of(2025, 1).atDay(28),
            YearMonth.of(2025, 1).atDay(29),
            YearMonth.of(2025, 1).atDay(30),
        )


        assertThat(result.getWorkDays("레오")).containsExactly(
            YearMonth.of(2025, 1).atDay(8),
            YearMonth.of(2025, 1).atDay(9),
            YearMonth.of(2025, 1).atDay(10),
            YearMonth.of(2025, 1).atDay(11),
            YearMonth.of(2025, 1).atDay(12),
            YearMonth.of(2025, 1).atDay(13),
            YearMonth.of(2025, 1).atDay(16),
            YearMonth.of(2025, 1).atDay(17),
            YearMonth.of(2025, 1).atDay(18),
            YearMonth.of(2025, 1).atDay(19),
            YearMonth.of(2025, 1).atDay(22),
            YearMonth.of(2025, 1).atDay(23),
            YearMonth.of(2025, 1).atDay(24),
            YearMonth.of(2025, 1).atDay(25),
            YearMonth.of(2025, 1).atDay(27),
            YearMonth.of(2025, 1).atDay(28),
            YearMonth.of(2025, 1).atDay(29),
            YearMonth.of(2025, 1).atDay(30),
            YearMonth.of(2025, 1).atDay(31),
            YearMonth.of(2025, 2).atDay(1),
        )
        assertThat(result.getOffDays("레오")).hasSize(8);
    }

    @Test
    fun `Parse 2502xlsx`() {
        // When
        val result = SungsimCakeParser().parseDayOff(
            YearMonth.of(2025, 2),
            Path("src/test/resources/duty-batch/sungsim-cake/12028_2_25년도2월휴무.xlsx").inputStream()
        )

        // Then
        assertThat(result.getNames()).containsExactlyInAnyOrder(
            "레오",
            "맥스",
            "노아",
            "루나",
            "제이",
            "자라",
            "리오",
            "니아",
            "벡스",
            "에이든",
            "카이",
            "주드",
            "테오",
            "다샤",
            "미오",
            "제이크",
            "엘라",
            "코비",
            "타이",
            "노엘",
            "루크",
            "켄지",
            "소니",
            "니키",
            "코라",
            "동현",
            "제시",
            "드루",
            "로이",
            "사라",
            "테라",
            "엘리",
            "리키",
            "벨라",
            "로건",
            "에이미"
        )

        assertThat(result.getOffDays("동현")).hasSize(10)
        assertThat(result.getOffDays("동현")).containsExactly(
            YearMonth.of(2025, 2).atDay(4),
            YearMonth.of(2025, 2).atDay(5),
            YearMonth.of(2025, 2).atDay(11),
            YearMonth.of(2025, 2).atDay(12),
            YearMonth.of(2025, 2).atDay(18),
            YearMonth.of(2025, 2).atDay(19),
            YearMonth.of(2025, 2).atDay(25),
            YearMonth.of(2025, 2).atDay(26),
            YearMonth.of(2025, 3).atDay(4),
            YearMonth.of(2025, 3).atDay(5),
        )
    }

}
