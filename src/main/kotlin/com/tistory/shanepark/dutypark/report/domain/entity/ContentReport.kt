package com.tistory.shanepark.dutypark.report.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.Lob
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction
import java.time.LocalDateTime

@Entity
@Table(
    name = "content_report",
    indexes = [
        Index(name = "idx_content_report_status_created", columnList = "status, created_date"),
        Index(name = "idx_content_report_reporter_target", columnList = "reporter_id, target_type, target_id"),
    ],
)
class ContentReport(
    /**
     * Nullable on purpose: reports are evidence and outlive the accounts involved.
     * The DB sets both member FKs to NULL on account deletion, so the *_name snapshots stay authoritative.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reporter_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    @field:JsonIgnore
    val reporter: Member?,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reported_member_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    @field:JsonIgnore
    val reportedMember: Member?,

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", nullable = false, length = 20)
    val targetType: ReportTargetType,

    @Column(name = "target_id", nullable = false, length = 36)
    val targetId: String,

    @Enumerated(EnumType.STRING)
    @Column(name = "reason", nullable = false, length = 30)
    val reason: ReportReason,

    @Column(name = "detail", length = 500)
    val detail: String? = null,

    @Lob
    @Column(name = "content_snapshot", nullable = false, columnDefinition = "TEXT")
    val contentSnapshot: String,

    @Column(name = "reporter_name", nullable = false, length = 50)
    val reporterName: String,

    @Column(name = "reported_member_name", nullable = false, length = 50)
    val reportedMemberName: String,
) : EntityBase() {

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    var status: ReportStatus = ReportStatus.OPEN

    @Column(name = "admin_memo", length = 1000)
    var adminMemo: String? = null

    @Column(name = "resolved_at")
    var resolvedAt: LocalDateTime? = null

    @Column(name = "resolved_by")
    var resolvedBy: Long? = null

}
