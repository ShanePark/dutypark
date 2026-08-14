package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class ProviderNeutralTermsAndAiPolicyMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.36__publish_provider_neutral_terms_and_ai_policy.sql"
    )

    @Test
    fun `migration publishes provider-neutral terms and AI policy without changing history or privacy policy`() {
        assertThat(Files.exists(migration)).isTrue()

        val sql = Files.readString(migration)

        assertThat(sql).contains("INSERT INTO policy_version", "WHERE NOT EXISTS")
        assertThat(sql).contains("'TERMS'", "'AI_SCHEDULE_PARSING'", "'2026-08-14'")
        assertThat(sql).doesNotContain("UPDATE policy_version", "'PRIVACY'", "member_consent")

        DriverManager.getConnection("jdbc:h2:mem:provider-neutral-policy-migration;MODE=MySQL").use { connection ->
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
                statement.execute(
                    """
                    INSERT INTO policy_version
                        (policy_type, version, content, effective_date, created_at)
                    VALUES
                        ('TERMS', '2026-08-13', 'Google legacy terms', '2026-08-13', NOW()),
                        ('AI_SCHEDULE_PARSING', '2026-08-13', 'Google legacy AI consent', '2026-08-13', NOW()),
                        ('PRIVACY', '2026-08-13', 'Google remains disclosed here', '2026-08-13', NOW())
                    """.trimIndent()
                )

                statement.execute(sql)
                statement.execute(sql)

                listOf("TERMS", "AI_SCHEDULE_PARSING").forEach { policyType ->
                    statement.executeQuery(
                        """
                        SELECT COUNT(*) AS policy_count
                        FROM policy_version
                        WHERE policy_type = '$policyType'
                          AND version = '2026-08-14'
                        """.trimIndent()
                    ).use { result ->
                        assertThat(result.next()).isTrue()
                        assertThat(result.getInt("policy_count")).isEqualTo(1)
                    }

                    statement.executeQuery(
                        """
                        SELECT version, effective_date, content
                        FROM policy_version
                        WHERE policy_type = '$policyType'
                        ORDER BY effective_date DESC
                        LIMIT 1
                        """.trimIndent()
                    ).use { result ->
                        assertThat(result.next()).isTrue()
                        assertThat(result.getString("version")).isEqualTo("2026-08-14")
                        assertThat(result.getObject("effective_date", LocalDate::class.java))
                            .isEqualTo(LocalDate.of(2026, 8, 14))
                        assertThat(result.getString("content"))
                            .doesNotContain("Google", "Gemini")
                    }
                }

                statement.executeQuery(
                    """
                    SELECT policy_type, version, content
                    FROM policy_version
                    WHERE version = '2026-08-13'
                    ORDER BY policy_type
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("policy_type")).isEqualTo("AI_SCHEDULE_PARSING")
                    assertThat(result.getString("content")).isEqualTo("Google legacy AI consent")
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("policy_type")).isEqualTo("PRIVACY")
                    assertThat(result.getString("content")).isEqualTo("Google remains disclosed here")
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("policy_type")).isEqualTo("TERMS")
                    assertThat(result.getString("content")).isEqualTo("Google legacy terms")
                    assertThat(result.next()).isFalse()
                }
            }
        }
    }

    @Test
    fun `new terms and AI consent are provider-neutral while retaining opt-in and revocation guarantees`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "AI 일정 시간 자동 인식",
            "외부 AI 처리 서비스",
            "별도의 선택 동의",
            "날짜와 시간을 직접 입력",
            "일정 날짜와 일정 내용 텍스트만 전송",
            "회원 식별자와 팀 식별자는 전송하지 않습니다",
            "실제 운영 제공자와 세부 처리 조건은 개인정보 처리방침",
            "동의 전에 일정 날짜나 내용 텍스트를 외부 AI 처리 서비스로 전송하지 않습니다",
            "서비스 설정에서 언제든 동의를 철회",
            "실제 외부 API 호출 직전에 현재 동의 상태와 정책 버전을 다시 확인",
            "일정 원문, AI 요청·응답 및 API 키는 기록하지 않습니다",
        )
        assertThat(sql).doesNotContain(
            "Google",
            "Gemini",
            "Generative Language API",
            "Google Cloud",
            "unpaid service",
            "paid service",
        )
    }
}
