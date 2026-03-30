package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.NotSupportedFileException
import com.tistory.shanepark.dutypark.duty.batch.exceptions.YearMonthNotMatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService
import com.tistory.shanepark.dutypark.duty.service.DutyService
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.whenever
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.YearMonth

class DutyBatchControllerTest : RestDocsTest() {

    @MockitoBean
    lateinit var dutyService: DutyService

    @MockitoBean
    lateinit var dutyBatchSungsimService: DutyBatchSungsimService

    @Test
    fun `batch upload returns unauthorized when login member cannot edit target duty`() {
        whenever(dutyService.canEdit(any(), eq(TestData.member.id!!))).thenReturn(false)

        mockMvc.perform(
            multipart("/api/duty_batch")
                .file(validFile())
                .param("memberId", TestData.member.id!!.toString())
                .param("year", "2026")
                .param("month", "3")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.unauthorized"))
    }

    @Test
    fun `batch upload requires template before invoking batch service`() {
        whenever(dutyService.canEdit(any(), eq(TestData.member.id!!))).thenReturn(true)
        teamRepository.findById(TestData.team.id!!).orElseThrow().apply {
            dutyBatchTemplate = null
            teamRepository.save(this)
        }

        mockMvc.perform(
            multipart("/api/duty_batch")
                .file(validFile())
                .param("memberId", TestData.member.id!!.toString())
                .param("year", "2026")
                .param("month", "3")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("dutyBatch.template.required"))
    }

    @Test
    fun `batch upload returns errorCode and errorDetails when file format is unsupported`() {
        whenever(dutyService.canEdit(any(), eq(TestData.member.id!!))).thenReturn(true)
        teamRepository.findById(TestData.team.id!!).orElseThrow().apply {
            dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE
            teamRepository.save(this)
        }
        whenever(
            dutyBatchSungsimService.batchUploadMember(any(), eq(TestData.member.id!!), eq(YearMonth.of(2026, 3)))
        ).thenThrow(NotSupportedFileException(".xls,.xlsx"))

        mockMvc.perform(
            multipart("/api/duty_batch")
                .file(validFile())
                .param("memberId", TestData.member.id!!.toString())
                .param("year", "2026")
                .param("month", "3")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.result").value(false))
            .andExpect(jsonPath("$.errorCode").value("dutyBatch.notSupportedFile"))
            .andExpect(jsonPath("$.errorDetails.supportedFile").value(".xls,.xlsx"))
    }

    @Test
    fun `batch upload returns year and month details for mismatched files`() {
        whenever(dutyService.canEdit(any(), eq(TestData.member.id!!))).thenReturn(true)
        teamRepository.findById(TestData.team.id!!).orElseThrow().apply {
            dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE
            teamRepository.save(this)
        }
        whenever(
            dutyBatchSungsimService.batchUploadMember(any(), eq(TestData.member.id!!), eq(YearMonth.of(2026, 3)))
        ).thenThrow(YearMonthNotMatchException(YearMonth.of(2026, 2)))

        mockMvc.perform(
            multipart("/api/duty_batch")
                .file(validFile())
                .param("memberId", TestData.member.id!!.toString())
                .param("year", "2026")
                .param("month", "3")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.result").value(false))
            .andExpect(jsonPath("$.errorCode").value("dutyBatch.yearMonthNotMatch"))
            .andExpect(jsonPath("$.errorDetails.year").value(2026))
            .andExpect(jsonPath("$.errorDetails.month").value(2))
    }

    private fun validFile(): MockMultipartFile {
        return MockMultipartFile(
            "file",
            "duty.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "dummy".toByteArray(),
        )
    }
}
