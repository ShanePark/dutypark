package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class ContentFilterTermsMigrationTest {

    private val root = Path.of(System.getProperty("user.dir"))
    private val previousTermsMigration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.41__publish_terms_with_community_guidelines.sql"
    )
    private val migration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.47__publish_terms_with_content_filter.sql"
    )

    @Test
    fun `migration publishes an idempotent latest terms version without touching other policies`() {
        assertThat(Files.exists(migration)).isTrue()

        val previousTermsSql = Files.readString(previousTermsMigration)
        val sql = Files.readString(migration)

        assertThat(sql).contains("INSERT INTO policy_version", "WHERE NOT EXISTS", "'TERMS'", "'2026-08-20'")
        assertThat(sql).doesNotContain(
            "UPDATE policy_version",
            "DELETE FROM policy_version",
            "'PRIVACY'",
            "'AI_SCHEDULE_PARSING'",
            "member_consent",
        )

        DriverManager.getConnection("jdbc:h2:mem:content-filter-terms-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute(
                    """
                    CREATE TABLE policy_version (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        policy_type VARCHAR(50) NOT NULL,
                        version VARCHAR(20) NOT NULL,
                        content TEXT NOT NULL,
                        effective_date DATE NOT NULL,
                        created_at DATETIME NOT NULL,
                        UNIQUE (policy_type, version)
                    )
                    """.trimIndent()
                )
                statement.execute(previousTermsSql)

                val previousTerms = statement.executeQuery(
                    """
                    SELECT content
                    FROM policy_version
                    WHERE policy_type = 'TERMS' AND version = '2026-08-18'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    result.getString("content")
                }

                statement.execute(sql)
                statement.execute(sql)

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS policy_count
                    FROM policy_version
                    WHERE policy_type = 'TERMS' AND version = '2026-08-20'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("policy_count")).isEqualTo(1)
                }

                // PolicyService.getCurrentPolicy semantics: latest version already in effect.
                statement.executeQuery(
                    """
                    SELECT version, effective_date, content
                    FROM policy_version
                    WHERE policy_type = 'TERMS' AND effective_date <= DATE '2026-08-20'
                    ORDER BY effective_date DESC
                    LIMIT 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("version")).isEqualTo("2026-08-20")
                    assertThat(result.getObject("effective_date", LocalDate::class.java))
                        .isEqualTo(LocalDate.of(2026, 8, 20))
                    assertThat(result.getString("content")).startsWith("Dutypark 이용약관")
                }

                statement.executeQuery(
                    """
                    SELECT content
                    FROM policy_version
                    WHERE policy_type = 'TERMS' AND version = '2026-08-18'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("content")).isEqualTo(previousTerms)
                }
            }
        }
    }

    @Test
    fun `latest terms describe filtering before posting instead of declining to pre-screen`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "시행일: 2026-08-20",
            "## 제8조 금지 콘텐츠",
            "서비스는 금지 콘텐츠 필터를 통해 명백한 위반 콘텐츠의 등록을 게시 시점에 차단하며",
            "신고 접수 후 제10조에 따라 조치합니다",
            "모든 이용자 콘텐츠를 상시 모니터링할 의무를 지는 것은 아닙니다",
            "- 공고일: 2026-08-20",
            "- 시행일: 2026-08-20",
            "종전 약관(시행일 2026-08-18)",
        )

        // App Store Guideline 1.2 requires a filter before posting; the old wording denied having one.
        assertThat(sql).doesNotContain("이용자 콘텐츠를 사전에 검열하지 않으며")

        // Every other article carries over unchanged.
        assertThat(sql).contains(
            "## 제7조 금지행위",
            "## 제9조 신고와 차단",
            "## 제10조 운영 조치와 제재 단계",
            "## 제11조 이의제기와 문의",
            "## 제12조 저작권",
            "## 제13조 책임 제한",
            "## 제14조 약관 변경과 동의",
            "## 제15조 준거법과 분쟁 해결",
        )
    }

    @Test
    fun `published terms only change the pre-screening clause`() {
        val previousContent = termsContent(Files.readString(previousTermsMigration))
        val currentContent = termsContent(Files.readString(migration))

        val previousLines = previousContent.lines()
        val currentLines = currentContent.lines()
        assertThat(currentLines).hasSameSizeAs(previousLines)

        val changed = previousLines.zip(currentLines).filter { (previous, current) -> previous != current }
        assertThat(changed.map { it.second }).allSatisfy { line ->
            assertThat(line).satisfiesAnyOf(
                { assertThat(it).contains("2026-08-20") },
                { assertThat(it).contains("금지 콘텐츠 필터") },
                { assertThat(it).contains("종전 약관(시행일 2026-08-18)") },
            )
        }
    }

    private fun termsContent(sql: String): String = sql
        .substringAfter("    'Dutypark 이용약관")
        .substringBefore("',\n    '2026-08-")
}
