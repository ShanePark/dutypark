package com.tistory.shanepark.dutypark.common.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.boot.context.properties.bind.Bindable
import org.springframework.boot.context.properties.bind.Binder
import org.springframework.boot.context.properties.source.ConfigurationPropertySource
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource
import org.springframework.util.unit.DataSize

class StoragePropertiesTest {

    @Test
    fun `should bind all properties correctly`() {
        val properties = mapOf(
            "dutypark.storage.root" to "test-storage",
            "dutypark.storage.max-file-size" to "100MB",
            "dutypark.storage.blacklist-ext[0]" to "exe",
            "dutypark.storage.blacklist-ext[1]" to "bat",
            "dutypark.storage.blacklist-ext[2]" to "sh",
            "dutypark.storage.thumbnail.max-side" to "300",
            "dutypark.storage.session-expiration-hours" to "48"
        )

        val source: ConfigurationPropertySource = MapConfigurationPropertySource(properties)
        val binder = Binder(source)
        val bound = binder.bind("dutypark.storage", Bindable.of(StorageProperties::class.java))

        assertThat(bound.isBound).isTrue()
        val storageProperties = bound.get()

        assertThat(storageProperties.root).isEqualTo("test-storage")
        assertThat(storageProperties.maxFileSize).isEqualTo(DataSize.ofMegabytes(100))
        assertThat(storageProperties.blacklistExt).containsExactly("exe", "bat", "sh")
        assertThat(storageProperties.thumbnail.maxSide).isEqualTo(300)
        assertThat(storageProperties.sessionExpirationHours).isEqualTo(48)
    }

    @Test
    fun `should use values from application yml when not overridden`() {
        val properties = mapOf(
            "dutypark.storage.root" to "/dutypark/storage",
            "dutypark.storage.max-file-size" to "50MB",
            "dutypark.storage.blacklist-ext[0]" to "exe",
            "dutypark.storage.blacklist-ext[1]" to "bat",
            "dutypark.storage.blacklist-ext[2]" to "cmd",
            "dutypark.storage.blacklist-ext[3]" to "sh",
            "dutypark.storage.thumbnail.max-side" to "200",
            "dutypark.storage.session-expiration-hours" to "24"
        )

        val source: ConfigurationPropertySource = MapConfigurationPropertySource(properties)
        val binder = Binder(source)
        val bound = binder.bind("dutypark.storage", Bindable.of(StorageProperties::class.java))

        assertThat(bound.isBound).isTrue()
        val storageProperties = bound.get()

        assertThat(storageProperties.root).isEqualTo("/dutypark/storage")
        assertThat(storageProperties.maxFileSize).isEqualTo(DataSize.ofMegabytes(50))
        assertThat(storageProperties.blacklistExt).containsExactly("exe", "bat", "cmd", "sh", "js")
        assertThat(storageProperties.thumbnail.maxSide).isEqualTo(200)
        assertThat(storageProperties.sessionExpirationHours).isEqualTo(24)
    }

    @Test
    fun `should allow empty blacklist`() {
        val properties = mapOf(
            "dutypark.storage.root" to "storage",
            "dutypark.storage.max-file-size" to "50MB",
            "dutypark.storage.thumbnail.max-side" to "200",
            "dutypark.storage.session-expiration-hours" to "24"
        )

        val source: ConfigurationPropertySource = MapConfigurationPropertySource(properties)
        val binder = Binder(source)
        val bound = binder.bind("dutypark.storage", Bindable.of(StorageProperties::class.java))

        assertThat(bound.isBound).isTrue()
        val storageProperties = bound.get()

        assertThat(storageProperties.blacklistExt).isEmpty()
    }
}
