package com.tistory.shanepark.dutypark.common.idempotency

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint

/**
 * Durable mapping from a client create operation to the resource it created.
 *
 * The row is created before the resource is created and held for the whole
 * create transaction. The create services serialize this short reservation
 * section with a pessimistic lock on the account's member row, so concurrent
 * retries cannot create two resources for the same client operation.
 */
@Entity
@Table(
    name = "create_idempotency_key",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_create_idempotency_member_operation_resource",
            columnNames = ["member_id", "operation_id", "resource_kind"]
        )
    ]
)
class CreateIdempotencyKey(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "operation_id", nullable = false, length = 36)
    val operationId: String,

    @Enumerated(EnumType.STRING)
    @Column(name = "resource_kind", nullable = false, length = 30)
    val resourceKind: CreateIdempotencyResource,

    @Column(name = "resource_id", length = 36)
    var resourceId: String? = null,
) : EntityBase()
