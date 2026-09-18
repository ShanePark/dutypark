package com.tistory.shanepark.dutypark.member.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class FriendDisplayOrderMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.54__rename_friend_pin_order_to_display_order.sql"
    )

    @Test
    fun `migration renames friend order column without losing existing order`() {
        assertThat(Files.exists(migration)).isTrue()

        DriverManager.getConnection("jdbc:h2:mem:friend-display-order-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute(
                    """
                    CREATE TABLE friends (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        pin_order BIGINT
                    )
                    """.trimIndent()
                )
                statement.execute("INSERT INTO friends (pin_order) VALUES (7)")
                statement.execute(Files.readString(migration).trim())

                connection.metaData.getColumns(null, null, "FRIENDS", null).use { columns ->
                    val names = buildSet {
                        while (columns.next()) add(columns.getString("COLUMN_NAME").uppercase())
                    }
                    assertThat(names).contains("DISPLAY_ORDER")
                    assertThat(names).doesNotContain("PIN_ORDER")
                }

                statement.executeQuery("SELECT display_order FROM friends").use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getLong("display_order")).isEqualTo(7L)
                }
            }
        }
    }
}
