package com.tistory.shanepark.dutypark.publiccontent.controller

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.publiccontent.domain.GuideContentResponse
import com.tistory.shanepark.dutypark.publiccontent.domain.ReleaseNotesResponse
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/public-content")
class PublicContentController(
    private val publicContentService: PublicContentService,
) {

    @GetMapping("/guide")
    fun getGuide(@RequestParam locale: String): ResponseEntity<GuideContentResponse> {
        validateLocale(locale)
        val content = publicContentService.getGuide(locale)
        return ResponseEntity.ok()
            .cacheControl(PUBLIC_CACHE_CONTROL)
            .eTag("guide-${content.contentVersion}-$locale")
            .body(content)
    }

    @GetMapping("/release-notes")
    fun getReleaseNotes(
        @RequestParam locale: String,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "5") size: Int,
    ): ResponseEntity<ReleaseNotesResponse> {
        validateLocale(locale)
        if (page < 0 || size !in 1..50) {
            throw BadRequestException()
        }
        val content = publicContentService.getReleaseNotes(locale, page, size)
        return ResponseEntity.ok()
            .cacheControl(PUBLIC_CACHE_CONTROL)
            .eTag("release-notes-${content.contentVersion}-$locale-$page-$size")
            .body(content)
    }

    private fun validateLocale(locale: String) {
        if (locale !in SUPPORTED_LOCALES) {
            throw BadRequestException()
        }
    }

    companion object {
        private val SUPPORTED_LOCALES = setOf("ko", "en")
        private val PUBLIC_CACHE_CONTROL = CacheControl.noCache().cachePublic().mustRevalidate()
    }
}
