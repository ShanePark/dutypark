package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class TermsAndAiPolicyMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.29__add_terms_and_ai_schedule_consent.sql"
    )

    @Test
    fun `migration creates one current terms and AI policy while preserving legacy policies`() {
        assertThat(Files.exists(migration)).isTrue()

        val sql = Files.readString(migration)

        assertThat(sql).contains("INSERT INTO policy_version", "WHERE NOT EXISTS")
        assertThat(sql).contains("'TERMS'", "'AI_SCHEDULE_PARSING'", "'2026-08-13'")
        assertThat(sql).contains(
            "CREATE TABLE IF NOT EXISTS ai_schedule_parsing_consent_event",
            "event_type VARCHAR(20) NOT NULL",
            "FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE",
            "INDEX idx_ai_schedule_parsing_consent_event_member_created (member_id, created_at, id)",
        )
        assertThat(sql).doesNotContain("UPDATE policy_version")

        DriverManager.getConnection("jdbc:h2:mem:terms-ai-policy-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute("CREATE TABLE member (id BIGINT AUTO_INCREMENT PRIMARY KEY)")
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
                        ('TERMS', '2025-01-15', 'legacy terms', '2025-01-15', NOW()),
                        ('AI_SCHEDULE_PARSING', '2026-01-01', 'legacy AI consent', '2026-01-01', NOW())
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
                        WHERE policy_type = '$policyType'
                        ORDER BY effective_date DESC
                        LIMIT 1
                        """.trimIndent()
                    ).use { result ->
                        assertThat(result.next()).isTrue()
                        assertThat(result.getString("version")).isEqualTo("2026-08-13")
                        assertThat(result.getObject("effective_date", LocalDate::class.java))
                            .isEqualTo(LocalDate.of(2026, 8, 13))
                    }
                }

                statement.executeQuery(
                    """
                    SELECT policy_type, version, content
                    FROM policy_version
                    WHERE (policy_type = 'TERMS' AND version = '2025-01-15')
                       OR (policy_type = 'AI_SCHEDULE_PARSING' AND version = '2026-01-01')
                    ORDER BY policy_type
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("policy_type")).isEqualTo("AI_SCHEDULE_PARSING")
                    assertThat(result.getString("version")).isEqualTo("2026-01-01")
                    assertThat(result.getString("content")).isEqualTo("legacy AI consent")
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("policy_type")).isEqualTo("TERMS")
                    assertThat(result.getString("version")).isEqualTo("2025-01-15")
                    assertThat(result.getString("content")).isEqualTo("legacy terms")
                    assertThat(result.next()).isFalse()
                }

                statement.execute("INSERT INTO member (id) VALUES (1)")
                statement.execute(
                    """
                    INSERT INTO ai_schedule_parsing_consent_event
                        (member_id, event_type, policy_version, created_at, ip_address, user_agent)
                    VALUES
                        (1, 'GRANTED', '2026-08-13', CURRENT_TIMESTAMP, '127.0.0.1', 'migration-test')
                    """.trimIndent()
                )
                statement.execute("DELETE FROM member WHERE id = 1")
                statement.executeQuery("SELECT COUNT(*) FROM ai_schedule_parsing_consent_event").use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt(1)).isZero()
                }
            }
        }
    }

    @Test
    fun `current terms cover actual service contracts without promising immediate deletion`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "웹과 iOS 앱",
            "계정과 인증",
            "Web Push와 iOS 푸시 알림",
            "Google AI를 이용한 일정 시간 자동 인식",
            "직접 입력하여 일정을 만들고 수정",
            "이용자 콘텐츠, 공유와 권한",
            "SCHEDULE·PROFILE·TEAM·TODO",
            "공동 TEAM 데이터",
            "권한이 이관될 수 있습니다",
            "계정 삭제는 안전한 정리와 권한 이관을 위해 비동기로 처리",
            "모든 데이터가 요청 즉시 일괄 삭제되는 것은 아닙니다",
            "소셜 제공자의 계정 자체를 삭제하는 절차가 아닙니다",
            "서비스 변경과 중단",
            "금지행위",
            "저작권",
            "책임 제한",
            "약관 변경과 동의",
            "대한민국 법률",
        )
        assertThat(sql).doesNotContain(
            "탈퇴 시 회원의 모든 데이터",
            "모든 데이터는 즉시 삭제",
        )
    }

    @Test
    fun `AI policy explains transfer scope consent revocation and last moment enforcement`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "Google Generative Language API",
            "일정 날짜와 일정 내용 텍스트만 전송",
            "회원 식별자와 팀 식별자는 전송하지 않습니다",
            "시작·종료 시간과 시간 표현을 제외한 제목을 추출",
            "unpaid service에 전송된 입력과 응답은 제품 및 머신러닝 기술 개선에 사용되거나 human reviewer가 처리",
            "개인정보나 기밀정보를 전송해서는 안 됩니다",
            "결제가 활성화된 Google Cloud Project의 paid service",
            "Google의 제품·모델 개선에 사용되지 않으며",
            "Google Cloud Data Processing Addendum(DPA)과 해당 서비스 약관",
            "production paid billing과 적용되는 DPA를 확인하기 전에는 AI 기능을 활성화하지 않습니다",
            "이 동의는 선택 사항입니다",
            "날짜와 시간을 직접 입력",
            "동의 전에 일정 날짜나 내용 텍스트를 Google Generative Language API로 전송하지 않습니다",
            "서비스 설정에서 언제든 동의를 철회",
            "실제 외부 API 호출 직전에 현재 동의 상태와 정책 버전을 다시 확인",
            "일정 원문, AI 요청·응답 및 API 키는 기록하지 않습니다",
        )
    }
}
