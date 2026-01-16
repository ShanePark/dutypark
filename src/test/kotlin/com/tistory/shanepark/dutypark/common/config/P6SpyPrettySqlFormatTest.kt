package com.tistory.shanepark.dutypark.common.config

import com.p6spy.engine.logging.Category
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class P6SpyPrettySqlFormatTest {

    private val formatter = P6SpyPrettySqlFormat()

    @Test
    fun `formatMessage returns sql when category is not statement`() {
        val result = formatter.formatMessage(
            connectionId = 1,
            now = "now",
            elapsed = 10,
            category = "DEBUG",
            prepared = null,
            sql = "select * from member",
            url = null
        )

        assertThat(result).contains("select * from member")
    }

    @Test
    fun `formatMessage formats ddl with stack trace`() {
        val result = formatter.formatMessage(
            connectionId = 1,
            now = "now",
            elapsed = 10,
            category = Category.STATEMENT.name,
            prepared = null,
            sql = "create table test (id int)",
            url = null
        )

        assertThat(result.lowercase()).contains("create")
        assertThat(result).contains("[${Category.STATEMENT.name}]")
    }

    @Test
    fun `formatMessage formats dml as basic`() {
        val result = formatter.formatMessage(
            connectionId = 1,
            now = "now",
            elapsed = 10,
            category = Category.STATEMENT.name,
            prepared = null,
            sql = "select * from schedule",
            url = null
        )

        assertThat(result.lowercase()).contains("select")
    }

    @Test
    fun `formatMessage handles null sql`() {
        val result = formatter.formatMessage(
            connectionId = 1,
            now = "now",
            elapsed = 10,
            category = Category.STATEMENT.name,
            prepared = null,
            sql = null,
            url = null
        )

        assertThat(result).contains("null")
    }
}
