package com.tistory.shanepark.dutypark.duty.batch

import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.batch.exceptions.YearMonthNotMatchException
import org.apache.poi.ss.usermodel.Cell
import org.apache.poi.ss.usermodel.Sheet
import org.apache.poi.ss.usermodel.WorkbookFactory
import org.springframework.stereotype.Component
import java.io.InputStream
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth

@Component
class SungsimCakeParser {

    fun parseDayOff(yearMonth: YearMonth, input: InputStream): BatchParseResult {
        val sheet = WorkbookFactory.create(input).first()
        val totalRows = sheet.physicalNumberOfRows
        val rowsInfo = getRowsInfo(sheet)
        val firstDate = calcFirstDate(yearMonth, rowsInfo)
        var curDate = firstDate
        val offDaysMap = mutableMapOf<String, MutableSet<LocalDate>>()

        for (i in 0 until rowsInfo.size) {
            val rowInfo = rowsInfo[i]
            val nextRowInfoIndex = if (i + 1 < rowsInfo.size) rowsInfo[i + 1].index else totalRows
            for (j in 0 until 7) {
                val dateCell = sheet.getRow(rowInfo.index).getCell(j * 3)
                if (curDate.dayOfMonth != cellToDate(dateCell)) {
                    throw YearMonthNotMatchException(yearMonth)
                }
                for (row in rowInfo.index + 1 until nextRowInfoIndex) {
                    val cell = sheet.getRow(row).getCell(1 + j * 3) ?: continue
                    val name = cellToName(cell)
                    if (name.isBlank())
                        continue
                    offDaysMap.computeIfAbsent(name) { mutableSetOf() }.add(curDate)
                }
                curDate = curDate.plusDays(1)
            }
        }
        return BatchParseResult(
            startDate = firstDate,
            endDate = curDate.minusDays(1),
            offDayResult = offDaysMap.filter { it.value.size != 1 }.toMap()
        )
    }

    private fun calcFirstDate(
        yearMonth: YearMonth,
        rowsInfo: MutableList<RowInfo>
    ): LocalDate {
        var startDate = yearMonth.atDay(rowsInfo[0].date)
        if (startDate.dayOfWeek != DayOfWeek.SUNDAY) {
            startDate = startDate.minusMonths(1)
            if (startDate.dayOfMonth < 15 || startDate.dayOfWeek != DayOfWeek.SUNDAY) {
                throw YearMonthNotMatchException(yearMonth)
            }
        }
        return startDate
    }

    private fun getRowsInfo(sheet: Sheet): MutableList<RowInfo> {
        val rowStartDates = mutableListOf<RowInfo>()
        for (i in 0 until sheet.physicalNumberOfRows) {
            val cell = sheet.getRow(i).getCell(0)
            if (cell.toString().isBlank())
                continue
            rowStartDates.add(RowInfo(index = i, date = cellToDate(cell)))
        }
        return rowStartDates
    }

    private fun cellToName(cell: Cell): String {
        val text = cell.toString()
        if (text.contains("("))
            return text.substring(0, text.indexOf("("))
        if (text.length == 1) {
            if (text == "월" || text == "화" || text == "수" || text == "목" || text == "금" || text == "토" || text == "일") {
                return ""
            }
        }
        return text
    }

    private fun cellToDate(cell: Cell): Int {
        var text = cell.toString()
        if (text.contains("/")) {
            text = text.substring(text.indexOf("/") + 1)
        }
        if (text.contains(".")) {
            text = text.substring(0, text.indexOf("."))
        }

        return text.replace("[^0-9]".toRegex(), "").toInt()
    }

    private data class RowInfo(val index: Int, val date: Int)

}
