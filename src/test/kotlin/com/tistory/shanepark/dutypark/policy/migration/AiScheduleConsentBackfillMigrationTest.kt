package com.tistory.shanepark.dutypark.policy.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class AiScheduleConsentBackfillMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.30__grant_ai_schedule_parsing_consent_to_existing_members.sql"
    )

    @Test
    fun `migration grants current AI consent only to existing members without an event`() {
        assertThat(Files.exists(migration)).isTrue()
        val sql = Files.readString(migration)

        assertThat(sql).contains(
            "INSERT INTO ai_schedule_parsing_consent_event",
            "'GRANTED'",
            "'2026-08-13'",
            "WHERE NOT EXISTS",
        )

        DriverManager.getConnection("jdbc:h2:mem:ai-consent-backfill;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute("CREATE TABLE member (id BIGINT AUTO_INCREMENT PRIMARY KEY)")
                statement.execute(
                    """
                    CREATE TABLE ai_schedule_parsing_consent_event (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        member_id BIGINT NOT NULL,
                        event_type VARCHAR(20) NOT NULL,
                        policy_version VARCHAR(20),
                        created_at DATETIME(6) NOT NULL,
                        ip_address VARCHAR(45),
                        user_agent VARCHAR(500)
                    )
                    """.trimIndent()
                )
                statement.execute("INSERT INTO member (id) VALUES (1), (2), (3)")
                statement.execute(
                    """
                    INSERT INTO ai_schedule_parsing_consent_event
                        (member_id, event_type, policy_version, created_at, ip_address, user_agent)
                    VALUES
                        (2, 'REVOKED', NULL, CURRENT_TIMESTAMP, '127.0.0.1', 'existing-revocation'),
                        (3, 'GRANTED', '2026-08-13', CURRENT_TIMESTAMP, '127.0.0.1', 'existing-grant')
                    """.trimIndent()
                )

                statement.execute(sql)
                statement.execute(sql)
                statement.execute("INSERT INTO member (id) VALUES (4)")

                statement.executeQuery(
                    """
                    SELECT event_type, policy_version, ip_address, user_agent, created_at
                    FROM ai_schedule_parsing_consent_event
                    WHERE member_id = 1
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("event_type")).isEqualTo("GRANTED")
                    assertThat(result.getString("policy_version")).isEqualTo("2026-08-13")
                    assertThat(result.getString("ip_address")).isNull()
                    assertThat(result.getString("user_agent")).isNull()
                    assertThat(result.getTimestamp("created_at")).isNotNull()
                    assertThat(result.next()).isFalse()
                }

                statement.executeQuery(
                    """
                    SELECT member_id, event_type, policy_version, ip_address, user_agent
                    FROM ai_schedule_parsing_consent_event
                    WHERE member_id IN (2, 3)
                    ORDER BY member_id
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getLong("member_id")).isEqualTo(2)
                    assertThat(result.getString("event_type")).isEqualTo("REVOKED")
                    assertThat(result.getString("policy_version")).isNull()
                    assertThat(result.getString("ip_address")).isEqualTo("127.0.0.1")
                    assertThat(result.getString("user_agent")).isEqualTo("existing-revocation")

                    assertThat(result.next()).isTrue()
                    assertThat(result.getLong("member_id")).isEqualTo(3)
                    assertThat(result.getString("event_type")).isEqualTo("GRANTED")
                    assertThat(result.getString("policy_version")).isEqualTo("2026-08-13")
                    assertThat(result.getString("ip_address")).isEqualTo("127.0.0.1")
                    assertThat(result.getString("user_agent")).isEqualTo("existing-grant")
                    assertThat(result.next()).isFalse()
                }

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS event_count
                    FROM ai_schedule_parsing_consent_event
                    WHERE member_id = 4
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("event_count")).isZero()
                }

                statement.executeQuery(
                    """
                    SELECT COUNT(*) AS event_count
                    FROM ai_schedule_parsing_consent_event
                    """.trimIndent()
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getInt("event_count")).isEqualTo(3)
                }
            }
        }
    }
}
