package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.batch.exceptions.MultipleNameFoundException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NameNotFoundException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NotSupportedFileException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.*
import org.springframework.mock.web.MockMultipartFile
import org.springframework.web.multipart.MultipartFile
import java.io.InputStream
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.*

@ExtendWith(MockitoExtension::class)
class DutyBatchSungsimServiceTest {

    @Mock
    private lateinit var sungsimCakeParser: SungsimCakeParser

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var dutyRepository: DutyRepository

    @Mock
    private lateinit var dutyTypeRepository: DutyTypeRepository

    private lateinit var dutyBatchService: DutyBatchSungsimService

    @BeforeEach
    fun setUp() {
        dutyBatchService = DutyBatchSungsimService(
            sungsimCakeParser,
            memberRepository,
            dutyRepository,
            dutyTypeRepository
        )
    }

    private fun createMultipartFile(fileName: String, content: ByteArray = ByteArray(0)): MultipartFile {
        return MockMultipartFile("file", fileName, "application/octet-stream", content)
    }

    private fun createValidXlsxFile(content: ByteArray = ByteArray(0), fileName: String = "test.xlsx"): MultipartFile {
        return MockMultipartFile(
            "file",
            fileName,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            content
        )
    }

    private fun createDummyMember(name: String, department: Department?): Member {
        val member = Member(name = name, email = null, password = "")
        member.department = department
        return member
    }

    @Test
    fun `sungsimDutyBatch throws exception when file is not xlsx`() {
        val file = createMultipartFile("test.txt")
        assertThrows<NotSupportedFileException> {
            dutyBatchService.batchUpload(file, 1L, YearMonth.of(2023, 1))
        }
    }

    @Test
    fun `sungsimDutyBatch throws exception when member not found`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {}
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.empty())

        assertThrows<NoSuchElementException> {
            dutyBatchService.batchUpload(file, 1L, yearMonth)
        }
    }


    @Test
    fun `sungsimDutyBatch throws exception when member has no department`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {}
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("John", null)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows<IllegalArgumentException> {
            dutyBatchService.batchUpload(file, 1L, yearMonth)
        }
        assertThat(exception.message).startsWith("Member has no department")
    }

    @Test
    fun `sungsimDutyBatch throws exception when validName contains multiple names`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {
            on { getNames() } doReturn listOf("John", "ohn")
        }
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("John", Department("dummy"))
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        assertThrows<MultipleNameFoundException> {
            dutyBatchService.batchUpload(file, 1L, yearMonth)
        }
    }

    @Test
    fun `sungsimDutyBatch throws exception when validName is empty`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {
            on { getNames() } doReturn listOf("Doe")
        }
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("John", Department("dummy"))
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        assertThrows<NameNotFoundException> {
            dutyBatchService.batchUpload(file, 1L, yearMonth)
        }
    }

    @Test
    fun `sungsimDutyBatch successfully processes and calls saveAll`() {
        val yearMonth = YearMonth.of(2023, 1)
        val offDays = listOf(
            LocalDate.of(2022, 12, 31),
            LocalDate.of(2023, 1, 1),
            LocalDate.of(2023, 1, 2)
        )
        val startDate = yearMonth.atDay(1).minusDays(1)
        val endDate = yearMonth.atEndOfMonth()
        val dummyBatchResult = mock<BatchParseResult> {
            on { getNames() } doReturn listOf("John")
            on { getWorkDays("John") } doReturn startDate.datesUntil(endDate).filter { it !in offDays }.toList()
        }
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val department = Department("dummy")
        val member = createDummyMember("John", department)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        val dutyType = DutyType(name = "dummy", position = 0, department = department)
        whenever(dutyTypeRepository.findAllByDepartment(department)).thenReturn(listOf(dutyType))

        dutyBatchService.batchUpload(createValidXlsxFile(), 1L, yearMonth)

        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
            member,
            dummyBatchResult.startDate,
            dummyBatchResult.endDate
        )

        argumentCaptor<List<Duty>>().apply {
            verify(dutyRepository).saveAll(capture())
            val capturedDuties = firstValue
            assertThat(capturedDuties.size)
                .isEqualTo(ChronoUnit.DAYS.between(startDate, endDate) - offDays.size)
            assertThat(capturedDuties.map { it.dutyDate })
                .containsExactlyElementsOf(dummyBatchResult.getWorkDays("John"))
        }
    }

}
