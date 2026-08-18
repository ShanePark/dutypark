package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class CommunityGuidelinesTermsMigrationTest {

    private val root = Path.of(System.getProperty("user.dir"))
    private val previousTermsMigration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.36__publish_provider_neutral_terms_and_ai_policy.sql"
    )
    private val migration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.41__publish_terms_with_community_guidelines.sql"
    )

    @Test
    fun `migration publishes an idempotent latest terms version without touching other policies`() {
        assertThat(Files.exists(migration)).isTrue()

        val previousTermsSql = Files.readString(previousTermsMigration)
        val sql = Files.readString(migration)

        assertThat(sql).contains("INSERT INTO policy_version", "WHERE NOT EXISTS", "'TERMS'", "'2026-08-18'")
        assertThat(sql).doesNotContain(
            "UPDATE policy_version",
            "DELETE FROM policy_version",
            "'PRIVACY'",
            "'AI_SCHEDULE_PARSING'",
            "member_consent",
        )

        DriverManager.getConnection("jdbc:h2:mem:community-guidelines-terms-migration;MODE=MySQL").use { connection ->
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
                    WHERE policy_type = 'TERMS' AND version = '2026-08-14'
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
                    WHERE policy_type = 'TERMS' AND version = '2026-08-18'
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
                    WHERE policy_type = 'TERMS' AND effective_date <= DATE '2026-08-18'
                    ORDER BY effective_date DESC
                    LIMIT 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("version")).isEqualTo("2026-08-18")
                    assertThat(result.getObject("effective_date", LocalDate::class.java))
                        .isEqualTo(LocalDate.of(2026, 8, 18))
                    assertThat(result.getString("content")).startsWith("Dutypark 이용약관")
                }

                statement.executeQuery(
                    """
                    SELECT content
                    FROM policy_version
                    WHERE policy_type = 'TERMS' AND version = '2026-08-14'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("content")).isEqualTo(previousTerms)
                }

                statement.executeQuery(
                    """
                    SELECT version
                    FROM policy_version
                    WHERE policy_type = 'AI_SCHEDULE_PARSING'
                    ORDER BY effective_date DESC
                    LIMIT 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("version")).isEqualTo("2026-08-14")
                }
            }
        }
    }

    @Test
    fun `latest terms document prohibited content, reporting, blocking, sanctions and appeals`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "시행일: 2026-08-18",
            "## 제8조 금지 콘텐츠",
            "타인을 비방하거나 괴롭히는 표현, 특정 개인이나 집단에 대한 혐오 표현",
            "음란물이나 성적 수치심을 유발하는 내용, 폭력적이거나 잔혹한 내용",
            "스팸, 반복 전송, 수신자가 원하지 않는 광고·홍보·판촉 내용",
            "다른 사람이나 단체를 사칭하거나",
            "불법 행위를 조장하거나 법령이 금지하는 정보",
            "동의 없이 게시한 타인의 개인정보나 사생활에 관한 정보",
            "## 제9조 신고와 차단",
            "신고 기능을 통해 다른 이용자, 일정 또는 Todo를 신고할 수 있습니다",
            "차단하면 서로의 친구·가족 관계가 해제되고",
            "서로의 달력 열람, 회원 검색, 친구 요청, 알림이 양방향으로 차단됩니다",
            "같은 팀에 속한 이용자의 근무표는 팀 운영에 필요하므로 차단 이후에도 계속 표시됩니다",
            "차단 목록에서 언제든 차단을 해제할 수 있습니다",
            "## 제10조 운영 조치와 제재 단계",
            "신고를 접수한 때부터 24시간 이내에 신고된 콘텐츠와 계정을 확인하고 필요한 조치를 합니다",
            "1) 경고",
            "2) 해당 콘텐츠 삭제",
            "3) 계정 이용 정지",
            "4) 이용계약 해지",
            "긴급하거나 중대한 위반에 대해서는 위 단계를 거치지 않고",
            "기존 로그인 세션은 모두 종료됩니다",
            "## 제11조 이의제기와 문의",
            "문의 페이지(/support)로 이의를 제기할 수 있습니다",
            "회신받을 이메일 주소와 이의 사유를 기재",
            "https://dutypark.o-r.kr/support",
            "- 공고일: 2026-08-18",
            "- 시행일: 2026-08-18",
        )

        // Articles carried over from the previous version keep their text and are only renumbered.
        assertThat(sql).contains(
            "## 제7조 금지행위",
            "## 제12조 저작권",
            "## 제13조 책임 제한",
            "## 제14조 약관 변경과 동의",
            "## 제15조 준거법과 분쟁 해결",
        )
        assertThat(sql).doesNotContain(
            "## 제8조 저작권",
            "## 제9조 책임 제한",
            "## 제10조 약관 변경과 동의",
            "## 제11조 준거법과 분쟁 해결",
            "Google",
            "Gemini",
        )
    }
}
