package com.tistory.shanepark.dutypark.publiccontent.controller

import com.tistory.shanepark.dutypark.TestUtils
import com.tistory.shanepark.dutypark.common.advice.RestExceptionControllerAdvice
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import org.hamcrest.Matchers.allOf
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.matchesPattern
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.test.web.servlet.setup.MockMvcBuilders

class PublicContentControllerTest {

    private lateinit var mockMvc: MockMvc

    @BeforeEach
    fun setup() {
        val service = PublicContentService(TestUtils.jsr310JsonMapper())
        mockMvc = MockMvcBuilders.standaloneSetup(PublicContentController(service))
            .setControllerAdvice(RestExceptionControllerAdvice())
            .build()
    }

    @Test
    fun `guide returns flattened localized content with cache headers`() {
        mockMvc.perform(get("/api/public-content/guide").param("locale", "en"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.locale").value("en"))
            .andExpect(jsonPath("$.title").value("Guide"))
            .andExpect(jsonPath("$.actions.expandAll").value("Expand all"))
            .andExpect(jsonPath("$.actions.collapseAll").value("Collapse all"))
            .andExpect(jsonPath("$.contentVersion").value(matchesPattern("[0-9a-f]{64}")))
            .andExpect(jsonPath("$.sections[0].id").value("dashboard"))
            .andExpect(
                header().string(
                    "Cache-Control",
                    allOf(
                        containsString("public"),
                        containsString("no-cache"),
                        containsString("must-revalidate"),
                        not(containsString("max-age")),
                    )
                )
            )
            .andExpect(header().exists("ETag"))
    }

    @Test
    fun `release notes returns requested page and exact labels contract`() {
        mockMvc.perform(
            get("/api/public-content/release-notes")
                .param("locale", "ko")
                .param("page", "1")
                .param("size", "5")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.page").value(1))
            .andExpect(jsonPath("$.size").value(5))
            .andExpect(jsonPath("$.items.length()").value(5))
            .andExpect(jsonPath("$.labels.title").value("변경사항"))
            .andExpect(jsonPath("$.labels.count").value("총 {count}개의 변경사항"))
            .andExpect(jsonPath("$.labels.loadMore").value("더보기"))
            .andExpect(jsonPath("$.labels.latest").value("최신"))
            .andExpect(jsonPath("$.labels.pr").value("PR #{number}"))
            .andExpect(jsonPath("$.labels.areas").value("영역"))
            .andExpect(jsonPath("$.labels.categoryLabels.feature").value("기능"))
            .andExpect(jsonPath("$.labels.areaLabels.ui").value("화면"))
            .andExpect(header().string("Cache-Control", containsString("public")))
            .andExpect(header().string("Cache-Control", containsString("no-cache")))
            .andExpect(header().string("Cache-Control", containsString("must-revalidate")))
            .andExpect(header().string("Cache-Control", not(containsString("max-age"))))
            .andExpect(header().exists("ETag"))
    }

    @Test
    fun `invalid locale page and size return bad request`() {
        listOf(
            "/api/public-content/guide?locale=ja",
            "/api/public-content/release-notes?locale=ja",
            "/api/public-content/release-notes?locale=ko&page=-1",
            "/api/public-content/release-notes?locale=ko&size=0",
            "/api/public-content/release-notes?locale=ko&size=51",
        ).forEach { path ->
            mockMvc.perform(get(path))
                .andExpect(status().isBadRequest)
                .andExpect(jsonPath("$.code").value("common.badRequest"))
        }
    }
}
