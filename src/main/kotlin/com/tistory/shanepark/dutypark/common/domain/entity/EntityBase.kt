package com.tistory.shanepark.dutypark.common.domain.entity

import com.github.f4b6a3.ulid.UlidCreator
import jakarta.persistence.*
import org.hibernate.annotations.JdbcTypeCode
import org.hibernate.proxy.HibernateProxy
import org.hibernate.type.SqlTypes
import org.springframework.data.annotation.CreatedDate
import org.springframework.data.annotation.LastModifiedDate
import org.springframework.data.domain.Persistable
import org.springframework.data.jpa.domain.support.AuditingEntityListener
import java.time.LocalDateTime
import java.util.*
import kotlin.jvm.Transient

@MappedSuperclass
@EntityListeners(AuditingEntityListener::class)
class EntityBase : Persistable<UUID> {

    @Id
    @Column(columnDefinition = "char(36)")
    @JdbcTypeCode(SqlTypes.VARCHAR)
    private val id: UUID = UlidCreator.getMonotonicUlid().toUuid()

    @Transient
    private var _isNew: Boolean = true

    override fun getId(): UUID {
        return id
    }

    override fun isNew(): Boolean {
        return _isNew
    }

    override fun equals(other: Any?): Boolean {
        if (other == null) {
            return false
        }
        if (other !is HibernateProxy && this::class != other::class) {
            return false
        }
        return id == getIdentifier(other)
    }

    private fun getIdentifier(obj: Any): Any {
        return if (obj is HibernateProxy) {
            obj.hibernateLazyInitializer.identifier
        } else {
            (obj as EntityBase).id
        }
    }

    override fun hashCode(): Int {
        return Objects.hashCode(id)
    }

    @PostPersist
    @PostLoad
    protected fun load() {
        _isNew = false
    }

    @LastModifiedDate
    @Column(name = "modified_date", updatable = true)
    var lastModifiedDate: LocalDateTime = LocalDateTime.now()

    @CreatedDate
    @Column(name = "created_date", updatable = false)
    var createdDate: LocalDateTime = LocalDateTime.now()

}
