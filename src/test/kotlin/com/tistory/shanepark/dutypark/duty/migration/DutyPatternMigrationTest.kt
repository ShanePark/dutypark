package com.tistory.shanepark.dutypark.duty.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.util.stream.Collectors

class DutyPatternMigrationTest {

    private val projectRoot: Path = Path.of(System.getProperty("user.dir"))
    private val schemaMigration = projectRoot.resolve(
        "src/main/resources/db/migration/v2/V2.2.18__member_duty_pattern.sql"
    )
    private val dataMigration = projectRoot.resolve(
        "src/main/resources/db/migration/v2/V2.2.19__migrate_weekday_patterns_and_hide_duty_types.sql"
    )

    @Test
    fun `pattern schema keeps history weekdays month locks and one override per date`() {
        val sql = Files.readString(schemaMigration)

        assertThat(sql).contains("CREATE TABLE member_duty_pattern")
        assertThat(sql).contains("effective_from")
        assertThat(sql).contains("effective_until_exclusive")
        assertThat(sql).contains("CREATE TABLE member_duty_pattern_weekday")
        assertThat(sql).contains("CREATE TABLE member_duty_pattern_month_lock")
        assertThat(sql).contains("UNIQUE (member_id, team_id, month_start)")
        assertThat(sql).contains("CREATE TABLE member_duty_pattern_month_lock_workday")
        assertThat(sql).contains("UNIQUE (member_id, duty_date)")
        assertThat(sql).contains("ADD COLUMN team_id BIGINT NULL")
    }

    @Test
    fun `weekday backfill is limited to single-type teams and preserves exceptional months`() {
        val sql = Files.readString(dataMigration)

        assertThat(sql).contains("WHERE t.work_type = 'WEEKDAY'")
        assertThat(sql).contains("ADD COLUMN hidden BIT NOT NULL DEFAULT 0")
        assertThat(sql).contains("HAVING COUNT(dt.id) = 1")
        assertThat(sql).contains("d.duty_date >= @pattern_effective_month")
        assertThat(sql).contains("FROM holiday h")
        assertThat(sql).contains("INSERT INTO member_duty_pattern_month_lock")
        assertThat(sql).contains("INSERT INTO member_duty_pattern_month_lock_workday")
        assertThat(sql).contains("LEFT JOIN member_duty_pattern_month_lock")

        val backfillPosition = sql.indexOf("INSERT INTO member_duty_pattern")
        val cleanupPosition = sql.indexOf("DELETE d\nFROM duty d")
        val dropPosition = sql.indexOf("DROP COLUMN work_type")
        assertThat(backfillPosition).isGreaterThanOrEqualTo(0)
        assertThat(cleanupPosition).isGreaterThan(backfillPosition)
        assertThat(dropPosition).isGreaterThan(cleanupPosition)
    }

    @Test
    fun `production Kotlin no longer references WorkType`() {
        val sourceRoot = projectRoot.resolve("src/main/kotlin")
        val referencedFiles = Files.walk(sourceRoot).use { paths ->
            paths
                .filter { Files.isRegularFile(it) && it.toString().endsWith(".kt") }
                .filter { Files.readString(it).contains("WorkType") }
                .map { sourceRoot.relativize(it).toString() }
                .sorted()
                .collect(Collectors.toList())
        }

        assertThat(referencedFiles).isEmpty()
    }
}
