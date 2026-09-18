package com.tistory.shanepark.dutypark.todo.domain.dto

import com.fasterxml.jackson.annotation.JsonProperty

data class TodoBulkDeleteResponse(
    val deletedCount: Int,
    val untaggedCount: Int,
) {
    /**
     * Kept for clients released before the split result counts were introduced.
     * It intentionally mirrors only the number of entities deleted, not untagged rows.
     */
    @get:JsonProperty("count")
    val count: Int
        get() = deletedCount
}
