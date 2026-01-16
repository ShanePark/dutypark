package com.tistory.shanepark.dutypark.common.domain.entity

import org.assertj.core.api.Assertions.assertThat
import org.hibernate.proxy.HibernateProxy
import org.hibernate.proxy.LazyInitializer
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.util.UUID

class EntityBaseTest {

    @Test
    fun `isNew flips after load`() {
        val entity = EntityBase()

        assertThat(entity.isNew()).isTrue

        val loadMethod = EntityBase::class.java.getDeclaredMethod("load")
        loadMethod.isAccessible = true
        loadMethod.invoke(entity)

        assertThat(entity.isNew()).isFalse
    }

    @Test
    fun `equals handles null and different types`() {
        val entity = EntityBase()

        assertThat(entity.equals(null)).isFalse
        assertThat(entity.equals("other")).isFalse
    }

    @Test
    fun `equals matches same instance and proxy identifier`() {
        val entity = EntityBase()
        val entityId = entity.getId()

        assertThat(entity.equals(entity)).isTrue

        val proxy = proxyWithId(entityId)
        assertThat(entity.equals(proxy)).isTrue

        val otherProxy = proxyWithId(UUID.randomUUID())
        assertThat(entity.equals(otherProxy)).isFalse
    }

    private fun proxyWithId(id: UUID): HibernateProxy {
        val lazyInitializer = mock<LazyInitializer>()
        whenever(lazyInitializer.identifier).thenReturn(id)
        val proxy = mock<HibernateProxy>()
        whenever(proxy.hibernateLazyInitializer).thenReturn(lazyInitializer)
        return proxy
    }
}
