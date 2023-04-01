package com.tistory.shanepark.dutypark.common.config

import com.p6spy.engine.logging.Category
import com.p6spy.engine.spy.P6SpyOptions
import com.p6spy.engine.spy.appender.MessageFormattingStrategy
import jakarta.annotation.PostConstruct
import org.hibernate.engine.jdbc.internal.FormatStyle
import org.springframework.context.annotation.Configuration
import org.springframework.util.ClassUtils
import java.util.*

@Configuration
class P6SpyPrettySqlFormat : MessageFormattingStrategy {

    @PostConstruct
    fun setLogMessageFormat() {
        P6SpyOptions.getActiveInstance().logMessageFormat = this.javaClass.name
    }

    override fun formatMessage(
        connectionId: Int,
        now: String?,
        elapsed: Long,
        category: String?,
        prepared: String?,
        sql: String?,
        url: String?
    ): String {
        return "\n[$category] | $elapsed ms | ${formatSql(category, sql)}"
    }

    private fun formatSql(category: String?, sql: String?): String? {
        if (sql != null && sql.trim().isNotEmpty() && Category.STATEMENT.name.equals(category)) {
            val trim = sql.trim().lowercase(Locale.ROOT)
            return stackTrace() + if (trim.startsWith("create") || trim.startsWith("alter") || trim.startsWith("comment")) {
                FormatStyle.DDL.formatter.format(sql)
            } else {
                FormatStyle.BASIC.formatter.format(sql)
            }
        }
        return sql
    }

    private fun stackTrace(): String {
        return Throwable().stackTrace.filter(::isDutyparkCode)
            .filter(::notFormatterStack)
            .filter(::notProxyStack)
            .filter(::notFilter)
            .toString()
    }

    private fun notFormatterStack(t: StackTraceElement) = !t.toString().contains(ClassUtils.getUserClass(this).name)
    private fun isDutyparkCode(t: StackTraceElement) = t.toString().startsWith("com.tistory.shanepark.dutypark")
    private fun notProxyStack(t: StackTraceElement) = !t.toString().contains("CGLIB")
    private fun notFilter(t: StackTraceElement) = !t.toString().contains(".doFilter")

}
