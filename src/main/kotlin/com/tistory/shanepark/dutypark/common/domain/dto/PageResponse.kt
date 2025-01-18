package com.tistory.shanepark.dutypark.common.domain.dto

import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable

class PageResponse<T>(page: Page<T>) {
    val content: List<T> = page.content
    val totalPages: Int = page.totalPages
    val totalElements: Long = page.totalElements
    val last: Boolean = page.isLast
    val first: Boolean = page.isFirst
    val size: Int = page.size
    val number: Int = page.number
    val numberOfElements: Int = page.numberOfElements
    val empty: Boolean = page.isEmpty
    val pageable: Pageable = page.pageable
}
