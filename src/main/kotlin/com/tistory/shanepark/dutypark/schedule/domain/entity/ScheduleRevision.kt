package com.tistory.shanepark.dutypark.schedule.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import jakarta.persistence.*
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction

@Entity
@Table(name = "schedule_revision", uniqueConstraints = [UniqueConstraint(columnNames = ["schedule_id", "version"])])
class ScheduleRevision(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "schedule_id", nullable = false, updatable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    val schedule: Schedule,
    @Column(nullable = false, updatable = false)
    val version: Long,
    @Column(name = "actor_id", updatable = false)
    val actorId: Long?,
    @Column(name = "actor_name", length = 50, updatable = false)
    val actorName: String?,
    @Column(nullable = false, length = 20, updatable = false)
    val source: String,
    @Lob
    @Column(name = "snapshot_json", nullable = false, columnDefinition = "LONGTEXT", updatable = false)
    val snapshotJson: String,
) : EntityBase()
