package com.tistory.shanepark.dutypark.member.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.util.stream.Collectors

class LegacySocialColumnsMigrationTest {

    private val projectRoot: Path = Path.of(System.getProperty("user.dir"))

    @Test
    fun `main kotlin code no longer references legacy social columns`() {
        val sourceRoot = projectRoot.resolve("src/main/kotlin")
        val referencedFiles = Files.walk(sourceRoot).use { paths ->
            paths
                .filter { Files.isRegularFile(it) && it.toString().endsWith(".kt") }
                .filter { path ->
                    val content = Files.readString(path)
                    content.contains("oauth_kakao_id") || content.contains("oauth_naver_id")
                }
                .map { sourceRoot.relativize(it).toString() }
                .sorted()
                .collect(Collectors.toList())
        }

        assertThat(referencedFiles).isEmpty()
    }

    @Test
    fun `latest migration drops legacy social columns and indexes`() {
        val migrationPath = projectRoot.resolve(
            "src/main/resources/db/migration/v2/V2.2.7__drop_legacy_social_id_columns.sql"
        )

        assertThat(Files.exists(migrationPath)).isTrue()

        val sql = Files.readString(migrationPath)
        assertThat(sql).contains("DROP INDEX uk_member_oauth_kakao_id")
        assertThat(sql).contains("DROP INDEX uk_member_oauth_naver_id")
        assertThat(sql).contains("DROP COLUMN oauth_kakao_id")
        assertThat(sql).contains("DROP COLUMN oauth_naver_id")
    }
}
