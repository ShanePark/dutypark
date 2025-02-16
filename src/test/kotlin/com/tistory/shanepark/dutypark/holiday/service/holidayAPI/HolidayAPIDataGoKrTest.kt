package com.tistory.shanepark.dutypark.holiday.service.holidayAPI

import com.tistory.shanepark.dutypark.common.datagokr.DataGoKrApi
import com.tistory.shanepark.dutypark.holiday.service.HolidayServiceTest
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import java.util.stream.IntStream

@ExtendWith(MockitoExtension::class)
class HolidayAPIDataGoKrTest {

    private val holiday2023 = HolidayServiceTest.holiday2023Dto()

    companion object {
        const val API_RESPONSE_2023 =
            "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><response><header><resultCode>00</resultCode><resultMsg>NORMAL SERVICE.</resultMsg></header><body><items><item><dateKind>01</dateKind><dateName>1월1일</dateName><isHoliday>Y</isHoliday><locdate>20230101</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>설날</dateName><isHoliday>Y</isHoliday><locdate>20230121</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>설날</dateName><isHoliday>Y</isHoliday><locdate>20230122</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>설날</dateName><isHoliday>Y</isHoliday><locdate>20230123</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>대체공휴일</dateName><isHoliday>Y</isHoliday><locdate>20230124</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>삼일절</dateName><isHoliday>Y</isHoliday><locdate>20230301</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>어린이날</dateName><isHoliday>Y</isHoliday><locdate>20230505</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>부처님오신날</dateName><isHoliday>Y</isHoliday><locdate>20230527</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>대체공휴일</dateName><isHoliday>Y</isHoliday><locdate>20230529</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>현충일</dateName><isHoliday>Y</isHoliday><locdate>20230606</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>제헌절</dateName><isHoliday>N</isHoliday><locdate>20230717</locdate><remarks>국경일이지만 공휴일 아님</remarks><seq>1</seq></item><item><dateKind>01</dateKind><dateName>광복절</dateName><isHoliday>Y</isHoliday><locdate>20230815</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>추석</dateName><isHoliday>Y</isHoliday><locdate>20230928</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>추석</dateName><isHoliday>Y</isHoliday><locdate>20230929</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>추석</dateName><isHoliday>Y</isHoliday><locdate>20230930</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>개천절</dateName><isHoliday>Y</isHoliday><locdate>20231003</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>한글날</dateName><isHoliday>Y</isHoliday><locdate>20231009</locdate><seq>1</seq></item><item><dateKind>01</dateKind><dateName>기독탄신일</dateName><isHoliday>Y</isHoliday><locdate>20231225</locdate><seq>1</seq></item></items><numOfRows>100</numOfRows><pageNo>1</pageNo><totalCount>18</totalCount></body></response>"
    }

    @Test
    fun getHolidayInfoTest(@Mock dataGoKrApi: DataGoKrApi) {
        `when`(dataGoKrApi.getHolidays(any(), any())).thenReturn(API_RESPONSE_2023)

        val holidayAPIDataGoKr = HolidayAPIDataGoKr(dataGoKrApi)
        HolidayAPIDataGoKr::class.java.getDeclaredField("serviceKey").apply {
            isAccessible = true
            set(holidayAPIDataGoKr, "SERVICE_KEY_HERE")
        }
        val result = holidayAPIDataGoKr.requestHolidays(2023)
        Assertions.assertThat(result).hasSize(holiday2023.size)
        IntStream.range(0, holiday2023.size).forEach { i ->
            Assertions.assertThat(result[i].dateName).isEqualTo(holiday2023[i].dateName)
            Assertions.assertThat(result[i].localDate).isEqualTo(holiday2023[i].localDate)
            Assertions.assertThat(result[i].isHoliday).isEqualTo(holiday2023[i].isHoliday)
        }
    }

    @Test
    fun parseTest(@Mock dataGoKrApi: DataGoKrApi) {
        val holidayAPIDataGoKr = HolidayAPIDataGoKr(dataGoKrApi)
        val result = holidayAPIDataGoKr.parse(API_RESPONSE_2023)
        Assertions.assertThat(result).hasSize(holiday2023.size)
        IntStream.range(0, holiday2023.size).forEach { i ->
            // Holiday name can be different depending on the API.
            Assertions.assertThat(result[i].dateName).isEqualTo(holiday2023[i].dateName)
            Assertions.assertThat(result[i].localDate).isEqualTo(holiday2023[i].localDate)
            Assertions.assertThat(result[i].isHoliday).isEqualTo(holiday2023[i].isHoliday)
        }
    }

}
