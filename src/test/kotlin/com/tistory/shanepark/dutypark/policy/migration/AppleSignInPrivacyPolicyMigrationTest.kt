package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import java.time.LocalDate

class AppleSignInPrivacyPolicyMigrationTest {
    private val root = Path.of(System.getProperty("user.dir"))
    private val basePrivacyMigration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.28__align_privacy_policy_with_current_data_flows.sql"
    )
    private val nativeAppleMigration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.32__publish_apple_sign_in_privacy_policy.sql"
    )
    private val migration = root.resolve(
        "src/main/resources/db/migration/v2/V2.2.35__publish_web_apple_sign_in_privacy_policy.sql"
    )

    @Test
    fun `migration publishes an idempotent latest privacy version without changing consent records`() {
        val basePrivacySql = Files.readString(basePrivacyMigration)
        val nativeAppleSql = Files.readString(nativeAppleMigration)
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "INSERT INTO policy_version",
            "'PRIVACY'",
            "'2026-08-15'",
            "previous.version = '2026-08-14'",
            "NOT EXISTS",
        )
        assertThat(sql).doesNotContain(
            "UPDATE policy_version",
            "DELETE FROM policy_version",
            "INSERT INTO member_consent",
            "UPDATE member_consent",
        )

        DriverManager.getConnection("jdbc:h2:mem:apple-privacy-policy;MODE=MySQL").use { connection ->
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
                statement.execute(basePrivacySql)
                statement.execute(nativeAppleSql)
                statement.execute(sql)
                statement.execute(sql)

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS policy_count
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY' AND version = '2026-08-15'
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
                    assertThat(result.getString("version")).isEqualTo("2026-08-15")
                    assertThat(result.getObject("effective_date", LocalDate::class.java))
                        .isEqualTo(LocalDate.of(2026, 8, 15))
                }

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS previous_count
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY' AND version = '2026-08-14'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("previous_count")).isEqualTo(1)
                }

                statement.executeQuery(
                    """
                    SELECT content
                    FROM policy_version
                    WHERE policy_type = 'PRIVACY' AND version = '2026-08-15'
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    val content = result.getString("content")
                    assertThat(content).contains(
                        "시행일: 2026-08-15",
                        "## 제10조 iOS 앱·웹 Sign in with Apple 처리",
                        "| Apple 회원가입·로그인·계정 연결 및 iOS 탈퇴 재인증 |",
                        "| Apple | Apple로부터 identity token, authorization code와 refresh token을 수신합니다.",
                        "provider(APPLE)",
                    )
                    assertThat(content).doesNotContain(
                        "## 제10조 iOS 전용 Sign in with Apple 처리",
                        "웹용 Apple 로그인이나 Apple Services ID 로그인은 제공하지 않습니다",
                    )
                    assertThat(content.split("- 공고일: 2026-08-14")).hasSize(2)
                }
            }
        }
    }

    @Test
    fun `latest privacy policy describes the complete cross platform Apple credential lifecycle`() {
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "iOS 앱과 웹에서 로그인, 신규 가입 및 기존 계정 연결에 Sign in with Apple",
            "Apple 재인증이 필요한 회원 탈퇴는 iOS 앱에서만 제공",
            "웹은 Apple Services ID와 등록된 Return URL",
            "이름과 이메일 scope를 요청하지 않습니다",
            "이메일이 같다는 이유만으로 기존 Dutypark 계정과 자동 병합하지 않습니다",
            "provider(APPLE)",
            "서버가 서명·issuer·audience·만료·발급 시각·nonce를 검증한 sub",
            "SHA-256 처리한 nonce와 비교용 state를 사용",
            "반환된 state 원문을 요청 값과 대조한 뒤 폐기",
            "identity token, authorization code, raw nonce와 state는 인증 요청 중에만 일시 처리",
            "token 원문 전체의 SHA-256 해시와 token 만료 시각만 저장",
            "Apple token endpoint(/auth/token)",
            "iOS App ID 또는 웹 Services ID인 client_id",
            "웹 인증에는 등록된 redirect_uri",
            "짧은 수명의 ES256 client_secret",
            "32-byte 전용 키로 AES-256-GCM 암호화",
            "refresh token을 발급받은 client_id",
            "가입을 완료하지 않아 어느 회원에게도 연결되지 않은 credential",
            "계정 연결 실패 후 새로 발급된 credential을 즉시 철회하지 못한 경우",
            "Apple sub 대신 무작위 내부 재시도 식별자와 함께 독립된 트랜잭션으로 암호화해 저장",
            "1일이 지난 orphan credential은 매일 정리 작업",
            "Apple revoke endpoint(/auth/revoke)",
            "Apple 측 권한을 먼저 철회",
            "철회가 실패하면 로컬 연결과 credential을 보존",
            "Apple 이름이나 이메일을 요청·공유·저장하지 않습니다",
        )
        assertThat(sql).doesNotContain(
            "APPLE_CLIENT_SECRET",
            "JWT secret으로 암호화",
            "Apple 이메일로 기존 계정을 자동",
            "웹용 Apple 로그인이나 Apple Services ID 로그인은 제공하지 않습니다",
            "SHA-256 처리한 nonce와 state를 사용",
            "계정 연결과 Apple 재인증이 필요한 회원 탈퇴는 iOS 앱에서만 제공",
            "iOS 계정 연결·탈퇴 재인증",
        )
    }
}
