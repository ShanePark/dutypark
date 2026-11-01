package com.tistory.shanepark.dutypark.security.oauth.mobile

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class MobileOAuthLinkAuthorizationMigrationTest {
    @Test
    fun `migration leaves existing and unverified transactions unauthorized for linking`() {
        val migration = Path.of(System.getProperty("user.dir")).resolve(
            "src/main/resources/db/migration/v2/V2.2.55__verify_mobile_oauth_link_authorization.sql"
        )
        DriverManager.getConnection("jdbc:h2:mem:mobile-oauth-link-authorization;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute("CREATE TABLE mobile_oauth_transaction (id BIGINT PRIMARY KEY)")
                statement.execute("INSERT INTO mobile_oauth_transaction (id) VALUES (1)")
                statement.execute(Files.readString(migration).trim())
                statement.execute("INSERT INTO mobile_oauth_transaction (id) VALUES (2)")
                statement.execute("INSERT INTO mobile_oauth_transaction (id, link_authorized) VALUES (3, TRUE)")
                statement.executeQuery("SELECT link_authorized FROM mobile_oauth_transaction ORDER BY id").use { result ->
                    val authorization = buildList {
                        while (result.next()) add(result.getBoolean("link_authorized"))
                    }
                    assertThat(authorization).containsExactly(false, false, true)
                }
            }
        }
    }
}
