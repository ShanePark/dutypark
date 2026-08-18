package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class UgcPrivacyPolicyMigrationTest {
    private val root = Path.of(System.getProperty("user.dir"))
    private val migrations = listOf(
        "V2.2.28__align_privacy_policy_with_current_data_flows.sql",
        "V2.2.32__publish_apple_sign_in_privacy_policy.sql",
        "V2.2.35__publish_web_apple_sign_in_privacy_policy.sql",
    ).map { root.resolve("src/main/resources/db/migration/v2/$it") }
    private val migration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.44__publish_ugc_privacy_policy.sql"
    )

    @Test
    fun `migration publishes one idempotent privacy version from the latest policy`() {
        assertThat(Files.exists(migration)).isTrue()

        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "INSERT INTO policy_version",
            "'PRIVACY'",
            "'2026-08-19'",
            "previous.version = '2026-08-15'",
            "NOT EXISTS",
        )
        assertThat(sql).doesNotContain(
            "UPDATE policy_version",
            "DELETE FROM policy_version",
            "INSERT INTO member_consent",
            "UPDATE member_consent",
        )

        DriverManager.getConnection("jdbc:h2:mem:ugc-privacy-policy;MODE=MySQL").use { connection ->
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
                migrations.forEach { statement.execute(Files.readString(it)) }
                statement.execute(sql)
                statement.execute(sql)

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS policy_count
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY' AND version = '2026-08-19'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("policy_count")).isEqualTo(1)
                }

                statement.executeQuery(
                    """
                    SELECT version, effective_date, content
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY'
                    ORDER BY effective_date DESC
                    LIMIT 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("version")).isEqualTo("2026-08-19")
                    assertThat(result.getObject("effective_date", LocalDate::class.java))
                        .isEqualTo(LocalDate.of(2026, 8, 19))
                    assertThat(result.getString("content")).contains(
                        "## 제10조 iOS 앱·웹 Sign in with Apple 처리",
                        "Apple Services ID",
                        "## 제11조 문의 및 신고 정보 처리",
                    )
                }
            }
        }
    }

    @Test
    fun `latest privacy policy describes inquiry and report processing and retention`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "비회원 문의 | 이메일, 제목, 본문, IP 주소",
            "회원 문의 | 회원 계정 연결, 이메일, 제목, 본문, IP 주소",
            "문의 접수·답변, 요청 이력 확인, 부정 이용 방지 및 운영·분쟁 대응",
            "신고자·피신고자 이름 snapshot",
            "신고 대상 종류와 식별자, 신고 사유와 상세 내용, 신고 대상 콘텐츠 snapshot",
            "처리 상태, 관리자 메모, 처리 시각 및 처리 관리자 식별자",
            "신고 접수·검토·조치, 반복 신고 확인, 서비스 안전 확보 및 운영·분쟁 대응",
            "계정 삭제 후에도 문의·신고 기록은 운영 및 분쟁 대응을 위해 보존",
            "회원 계정과의 연결은 해제",
            "고정된 자동 삭제 주기는 현재 운영하지 않습니다",
            "보존 목적이 달성되고 관련 분쟁 가능성 또는 법령상 보존 필요가 없어진 경우 삭제하거나 익명화",
        )
        assertThat(sql).doesNotContain(
            "Slack",
            "계정 삭제 즉시 문의·신고 기록을 삭제",
        )
    }
}
