package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyTypeNotSingleException
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
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
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
    private lateinit var teamRepository: TeamRepository

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
            teamRepository,
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

    private fun createDummyMember(name: String, team: Team?): Member {
        val member = Member(name = name, email = null, password = "")
        member.team = team
        return member
    }

    @Test
    fun `sungsimDutyBatch throws exception when file is not xlsx`() {
        val file = createMultipartFile("test.txt")
        assertThrows<NotSupportedFileException> {
            dutyBatchService.batchUploadMember(file, 1L, YearMonth.of(2023, 1))
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
            dutyBatchService.batchUploadMember(file, 1L, yearMonth)
        }
    }


    @Test
    fun `sungsimDutyBatch throws exception when member has no team`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {}
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("John", null)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows<IllegalArgumentException> {
            dutyBatchService.batchUploadMember(file, 1L, yearMonth)
        }
        assertThat(exception.message).startsWith("Member has no team")
    }

    @Test
    fun `sungsimDutyBatch throws exception when validName contains multiple names`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {
            on { findValidNames("홍길동") } doReturn listOf("홍길동", "길동")
        }
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("홍길동", Team("dummy"))
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        assertThrows<MultipleNameFoundException> {
            dutyBatchService.batchUploadMember(file, 1L, yearMonth)
        }
    }

    @Test
    fun `sungsimDutyBatch throws exception when validName is empty`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val dummyBatchResult = mock<BatchParseResult> {
            on { findValidNames("John") } doReturn emptyList()
        }
        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(dummyBatchResult)
        val member = createDummyMember("John", Team("dummy"))
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        assertThrows<NameNotFoundException> {
            dutyBatchService.batchUploadMember(file, 1L, yearMonth)
        }
    }

    @Test
    fun `sungsimDutyBatch successfully processes and calls saveAll`() {
        // Given
        val yearMonth = YearMonth.of(2023, 1)
        val offDays = listOf(
            LocalDate.of(2022, 12, 31),
            LocalDate.of(2023, 1, 1),
            LocalDate.of(2023, 1, 2)
        )
        val startDate = yearMonth.atDay(1).minusDays(1)
        val endDate = yearMonth.atEndOfMonth()

        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(
            BatchParseResult(
                startDate = startDate,
                endDate = endDate,
                offDayResult = mapOf("John" to offDays.toSet())
            )
        )
        val team = Team("dummy")
        val member = createDummyMember("John", team)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        val dutyType = DutyType(name = "dummy", position = 0, team = team, "#ffb3ba")
        whenever(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(dutyType))

        // When
        dutyBatchService.batchUploadMember(createValidXlsxFile(), 1L, yearMonth)

        // Then
        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
            member,
            startDate,
            endDate
        )

        argumentCaptor<List<Duty>>().apply {
            verify(dutyRepository).saveAll(capture())
            val capturedDuties = firstValue
            assertThat(capturedDuties.size)
                .isEqualTo(ChronoUnit.DAYS.between(startDate, endDate) + 1 - offDays.size)
            assertThat(capturedDuties.map { it.dutyDate })
                .containsExactlyElementsOf(
                    BatchParseResult(
                        startDate = startDate,
                        endDate = endDate,
                        offDayResult = mapOf("John" to offDays.toSet())
                    ).getWorkDays("John")
                )
        }
    }

    @Test
    fun `batchUploadteam throws exception when file is not xlsx`() {
        val file = createMultipartFile("test.txt")
        assertThrows<NotSupportedFileException> {
            dutyBatchService.batchUploadTeam(file, 1L, YearMonth.of(2023, 1))
        }
    }

    @Test
    fun `batchUploadteam throws exception when team not found`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        whenever(teamRepository.findById(1L)).thenReturn(Optional.empty())

        assertThrows<NoSuchElementException> {
            dutyBatchService.batchUploadTeam(file, 1L, yearMonth)
        }
    }

    @Test
    fun `batchUploadteam throws DutyTypeNotSingleException when multiple duty types found`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val team = Team("dummy")
        whenever(teamRepository.findById(1L)).thenReturn(Optional.of(team))
        // dutyTypeRepository 가 여러 개의 DutyType 을 반환하면 예외 발생
        val dutyType1 = DutyType(name = "dummy1", position = 0, team = team, "#98fb98")
        val dutyType2 = DutyType(name = "dummy2", position = 1, team = team, "#f0f8ff")
        whenever(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(dutyType1, dutyType2))

        assertThrows<DutyTypeNotSingleException> {
            dutyBatchService.batchUploadTeam(file, 1L, yearMonth)
        }
    }

    @Test
    fun `batchUploadteam successfully processes members and creates non-members`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val startDate = LocalDate.of(2023, 1, 1)
        val endDate = LocalDate.of(2023, 1, 31)

        val batchParseResult = mock<BatchParseResult>()
        whenever(batchParseResult.getNames()).thenReturn(listOf("Alice", "Bob"))
        whenever(batchParseResult.findValidNames("Alice")).thenReturn(listOf("Alice"))
        whenever(batchParseResult.getWorkDays("Alice")).thenReturn(
            listOf(
                LocalDate.of(2023, 1, 5),
                LocalDate.of(2023, 1, 6)
            )
        )
        whenever(batchParseResult.getOffDays("Alice")).thenReturn(emptyList())
        whenever(batchParseResult.startDate).thenReturn(startDate)
        whenever(batchParseResult.endDate).thenReturn(endDate)

        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(batchParseResult)

        val team = Team("dummy")
        val alice = createDummyMember("Alice", team)
        team.members.add(alice)
        whenever(teamRepository.findById(1L)).thenReturn(Optional.of(team))

        val dutyType = DutyType(name = "dummyDuty", position = 0, team = team, "#ffb3ba")
        whenever(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(dutyType))

        val result = dutyBatchService.batchUploadTeam(file, 1L, yearMonth)

        argumentCaptor<Member>().apply {
            verify(memberRepository).save(capture())
            val savedMember = firstValue
            assertThat(savedMember.name).isEqualTo("Bob")
            assertThat(savedMember.team).isEqualTo(team)
        }

        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(alice, startDate, endDate)
        argumentCaptor<List<Duty>>().apply {
            verify(dutyRepository).saveAll(capture())
            val duties = firstValue
            assertThat(duties.size).isEqualTo(2)
            assertThat(duties.map { it.dutyDate })
                .containsExactlyElementsOf(listOf(LocalDate.of(2023, 1, 5), LocalDate.of(2023, 1, 6)))
        }

        assertThat(result.startDate).isEqualTo(startDate)
        assertThat(result.endDate).isEqualTo(endDate)
        assertThat(result.dutyBatchResult).hasSize(2)
        val aliceResult = result.dutyBatchResult.first { it.first == "Alice" }.second
        assertThat(aliceResult.workingDays).isEqualTo(2)
        assertThat(aliceResult.offDays).isEqualTo(0)
    }


    @Test
    fun `batchUploadteam returns failure for member with multiple valid names`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val startDate = LocalDate.of(2023, 1, 1)
        val endDate = LocalDate.of(2023, 1, 31)

        val batchParseResult = mock<BatchParseResult>()
        whenever(batchParseResult.getNames()).thenReturn(listOf("Charlie"))
        whenever(batchParseResult.findValidNames("Charlie")).thenReturn(listOf("Charlie", "Charles"))
        whenever(batchParseResult.startDate).thenReturn(startDate)
        whenever(batchParseResult.endDate).thenReturn(endDate)

        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(batchParseResult)

        val team = Team("dummy")
        val charlie = createDummyMember("Charlie", team)
        team.members.add(charlie)
        whenever(teamRepository.findById(1L)).thenReturn(Optional.of(team))

        val dutyType = DutyType(name = "dummyDuty", position = 0, team = team, "#ffb3ba")
        whenever(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(dutyType))

        val result = dutyBatchService.batchUploadTeam(file, 1L, yearMonth)

        verify(dutyRepository, never()).deleteDutiesByMemberAndDutyDateBetween(any(), any(), any())
        verify(dutyRepository, never()).saveAll(any<List<Duty>>())

        assertThat(result.dutyBatchResult).hasSize(1)
        val expectedFailResult = DutyBatchResult.fail(MultipleNameFoundException::class.simpleName!!)
        assertThat(result.dutyBatchResult.first().second).isEqualTo(expectedFailResult)
    }

    @Test
    fun `batchUploadteam returns failure for member with no valid names`() {
        val file = createValidXlsxFile()
        val yearMonth = YearMonth.of(2023, 1)
        val startDate = LocalDate.of(2023, 1, 1)
        val endDate = LocalDate.of(2023, 1, 31)

        val batchParseResult = mock<BatchParseResult>()
        whenever(batchParseResult.getNames()).thenReturn(emptyList())
        whenever(batchParseResult.findValidNames("Dana")).thenReturn(emptyList())
        whenever(batchParseResult.startDate).thenReturn(startDate)
        whenever(batchParseResult.endDate).thenReturn(endDate)

        whenever(sungsimCakeParser.parseDayOff(eq(yearMonth), any<InputStream>())).thenReturn(batchParseResult)

        val team = Team("dummy")
        val dana = createDummyMember("Dana", team)
        team.members.add(dana)
        whenever(teamRepository.findById(1L)).thenReturn(Optional.of(team))

        val dutyType = DutyType(name = "dummyDuty", position = 0, team = team, "#ffb3ba")
        whenever(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(dutyType))

        val result = dutyBatchService.batchUploadTeam(file, 1L, yearMonth)
        assertThat(result.dutyBatchResult).hasSize(1)
        val expectedFailResult = DutyBatchResult.fail(NameNotFoundException::class.simpleName!!)
        assertThat(result.dutyBatchResult.first().second).isEqualTo(expectedFailResult)
    }

}
