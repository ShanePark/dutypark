package com.tistory.shanepark.dutypark.common.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.boot.env.YamlPropertySourceLoader
import org.springframework.core.io.FileSystemResource

class DevToolsConfigurationTest {

    private val properties = YamlPropertySourceLoader()
        .load("application", FileSystemResource("src/main/resources/application.yml"))
        .first()

    @Test
    fun `flyway migration files do not trigger devtools restart`() {
        assertThat(properties.getProperty("spring.devtools.restart.additional-exclude"))
            .isEqualTo("db/migration/**")
    }
}
