package com.tistory.shanepark.dutypark.inquiry.migration

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager

class InquiryMigrationTest {

    private val migration = Path.of(System.getProperty("user.dir")).resolve(
        "src/main/resources/db/migration/v2/V2.2.40__inquiry.sql"
    )

    @Test
    fun `migration creates inquiry table whose member reference is nullified when the member is deleted`() {
        assertThat(Files.exists(migration)).isTrue()

        val sql = Files.readString(migration)
        assertThat(sql).contains("CREATE TABLE inquiry", "ON DELETE SET NULL")

        DriverManager.getConnection("jdbc:h2:mem:inquiry-migration;MODE=MySQL").use { connection ->
            connection.createStatement().use { statement ->
                statement.execute(
                    """
                    CREATE TABLE member (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(10) NOT NULL
                    )
                    """.trimIndent()
                )
                statement.execute("INSERT INTO member (name) VALUES ('tester')")

                sql.split(";").map(String::trim).filter(String::isNotEmpty).forEach(statement::execute)

                statement.execute(
                    """
                    INSERT INTO inquiry
                        (id, member_id, email, subject, content, ip_address, status, created_date, modified_date)
                    VALUES
                        ('01J0000000000000000000000A', 1, 'tester@dutypark.o-r.kr', '제목', '내용', '127.0.0.1', 'OPEN', NOW(6), NOW(6))
                    """.trimIndent()
                )
                statement.execute("DELETE FROM member WHERE id = 1")

                statement.executeQuery("SELECT COUNT(*) AS remaining FROM inquiry WHERE member_id IS NULL").use { rs ->
                    assertThat(rs.next()).isTrue()
                    assertThat(rs.getInt("remaining")).isEqualTo(1)
                }
            }
        }
    }
}
