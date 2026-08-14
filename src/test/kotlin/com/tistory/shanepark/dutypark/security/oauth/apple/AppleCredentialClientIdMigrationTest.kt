package com.tistory.shanepark.dutypark.security.oauth.apple

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class AppleCredentialClientIdMigrationTest {
    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.34__store_apple_oauth_credential_client_id.sql"
    )

    @Test
    fun `migration adds nullable client id without rewriting legacy credentials`() {
        val sql = Files.readString(migration)
        assertThat(sql).contains(
            "ADD COLUMN client_id VARCHAR(255) NULL",
            "DROP INDEX uk_apple_oauth_credential_provider_social\n    ON apple_oauth_credential",
            "UNIQUE (provider, social_id, client_id)",
        )

        DriverManager.getConnection("jdbc:h2:mem:apple-client-id-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute(
                    """
                    CREATE TABLE apple_oauth_credential (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        provider VARCHAR(20) NOT NULL,
                        social_id VARCHAR(255) NOT NULL,
                        encrypted_refresh_token TEXT NOT NULL,
                        created_at DATETIME(6) NOT NULL,
                        updated_at DATETIME(6) NOT NULL
                    )
                    """.trimIndent()
                )
                statement.execute(
                    """
                    CREATE UNIQUE INDEX uk_apple_oauth_credential_provider_social
                    ON apple_oauth_credential (provider, social_id)
                    """.trimIndent()
                )
                statement.execute(
                    """
                    INSERT INTO apple_oauth_credential (
                        provider, social_id, encrypted_refresh_token, created_at, updated_at
                    ) VALUES ('APPLE', 'legacy-subject', 'encrypted', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """.trimIndent()
                )
                statement.execute(
                    sql.replace(
                        "DROP INDEX uk_apple_oauth_credential_provider_social\n    ON apple_oauth_credential",
                        "DROP INDEX uk_apple_oauth_credential_provider_social",
                    )
                )

                statement.executeQuery(
                    "SELECT client_id FROM apple_oauth_credential WHERE social_id = 'legacy-subject'"
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("client_id")).isNull()
                }

                statement.execute(
                    """
                    INSERT INTO apple_oauth_credential (
                        provider, social_id, client_id, encrypted_refresh_token, created_at, updated_at
                    ) VALUES
                        ('APPLE', 'shared-subject', 'native-client', 'native', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                        ('APPLE', 'shared-subject', 'web-client', 'web', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """.trimIndent()
                )
                assertThrows<java.sql.SQLException> {
                    statement.execute(
                        """
                        INSERT INTO apple_oauth_credential (
                            provider, social_id, client_id, encrypted_refresh_token, created_at, updated_at
                        ) VALUES (
                            'APPLE', 'shared-subject', 'web-client', 'duplicate', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """.trimIndent()
                    )
                }
            }
        }
    }
}
