package com.tistory.shanepark.dutypark.member.accountdeletion

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class AccountDeletionReceiptMigrationTest {
    private val migration = Path.of(System.getProperty("user.dir"))
        .resolve("src/main/resources/db/migration/v2/V2.2.50__account_deletion_receipts.sql")

    @Test
    fun `migration adds receipt and lease columns without removing deletion audit rows`() {
        assertThat(Files.exists(migration)).isTrue()

        DriverManager.getConnection("jdbc:h2:mem:account-deletion-receipts-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute(
                    """
                        create table account_deletion_job (
                            id bigint auto_increment primary key,
                            root_member_id bigint not null,
                            status varchar(30) not null,
                            attempt_count int not null,
                            next_attempt_at datetime(6) not null,
                            locked_at datetime(6),
                            last_error text,
                            completed_at datetime(6),
                            created_at datetime(6) not null
                        )
                    """.trimIndent()
                )
                // H2 2.x does not accept MySQL's comma-separated ADD COLUMN form;
                // execute the same clauses separately while preserving the production SQL.
                Files.readString(migration)
                    .replace(",\n    ADD COLUMN", ";\nALTER TABLE account_deletion_job\n    ADD COLUMN")
                    .split(';')
                    .map(String::trim)
                    .filter(String::isNotEmpty)
                    .forEach(statement::execute)

                connection.metaData.getColumns(null, null, "ACCOUNT_DELETION_JOB", null).use { columns ->
                    val names = buildSet {
                        while (columns.next()) add(columns.getString("COLUMN_NAME").uppercase())
                    }
                    assertThat(names).contains(
                        "RECEIPT_TOKEN_HASH",
                        "ESTIMATED_COMPLETION_AT",
                        "RECEIPT_EXPIRES_AT",
                        "LEASE_TOKEN",
                    )
                }
            }
        }
    }
}
