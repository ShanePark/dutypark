package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class PrivacyPolicyMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.28__align_privacy_policy_with_current_data_flows.sql"
    )

    @Test
    fun `migration creates an idempotent current privacy policy version`() {
        assertThat(Files.exists(migration)).isTrue()

        val sql = Files.readString(migration)

        assertThat(sql).contains("INSERT INTO policy_version")
        assertThat(sql).contains("'PRIVACY'", "'2026-08-13'", "WHERE NOT EXISTS")
        assertThat(sql).contains("policy_type = 'PRIVACY'", "version = '2026-08-13'")
        assertThat(sql).doesNotContain("UPDATE policy_version")

        DriverManager.getConnection("jdbc:h2:mem:privacy-policy-migration;MODE=MySQL").use { connection ->
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
                        ('PRIVACY', '2026-03-10', 'legacy privacy', '2026-03-10', NOW())
                    """.trimIndent()
                )
                statement.execute(sql)
                statement.execute(sql)

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS policy_count
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY'
                      AND version = '2026-08-13'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("policy_count")).isEqualTo(1)
                }

                statement.executeQuery(
                    """
                    SELECT version, effective_date
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY'
                    ORDER BY effective_date DESC
                    LIMIT 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("version")).isEqualTo("2026-08-13")
                    assertThat(result.getObject("effective_date", LocalDate::class.java))
                        .isEqualTo(LocalDate.of(2026, 8, 13))
                }

                statement.executeQuery(
                    """
                    SELECT content
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY'
                      AND version = '2026-03-10'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("content")).isEqualTo("legacy privacy")
                }
            }
        }
    }

    @Test
    fun `current policy describes cookie push attachment and social login data flows`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "bcrypt 해시 비밀번호",
            "access_token과 refresh_token이라는 HttpOnly 쿠키",
            "Web Push provider의 404·410 응답, APNs의 410 응답",
            "미완료 upload session은 24시간 유효하고 매일 02시 정리",
            "공급자 프로필 이름이나 이메일은 요청하거나 저장하지 않습니다",
            "provider access token은 공급자 고유 식별자를 조회하는 데만 사용",
            "Google Generative Language API(Gemini)",
            "AI_SCHEDULE_PARSING 현행 버전에 명시적으로 선택 동의한 경우에만",
            "큐의 외부 API 호출 직전에 현재 동의와 정책 버전을 다시 확인",
            "Cloud Billing이 활성화된 paid service",
            "Data Processing Addendum(DPA)",
            "확인한 Cloud Project의 API key만 구성",
            "unpaid service에는 일정 날짜나 내용 텍스트를 전송하지 않습니다",
            "운영 파일 로그 | 최대 365일간 보유",
            "localStorage에 인증 토큰을 저장하지 않습니다",
            "UserDefaults에 인증 토큰을 저장하지 않습니다",
        )
        assertThat(sql).doesNotContain(
            "쿠키를 사용하지 않으며",
            "브라우저 로컬 스토리지에 인증 토큰",
            "동의 여부와 관계없이 Google",
            "unpaid service를 이용해",
            "AI_SCHEDULE_PARSING_ENABLED",
        )
    }
}
