package com.tistory.shanepark.dutypark.inquiry.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Index
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction
import java.time.LocalDateTime

@Entity
@Table(
    name = "inquiry",
    indexes = [
        Index(name = "idx_inquiry_status_created", columnList = "status, created_date"),
        Index(name = "idx_inquiry_ip_created", columnList = "ip_address, created_date"),
        Index(name = "idx_inquiry_member_created", columnList = "member_id, created_date"),
    ],
)
class Inquiry(
    // 작성자가 탈퇴해도 문의 기록은 남아야 하므로 회원 삭제 시 FK 를 NULL 로 만든다.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    val member: Member? = null,

    // 로그인 회원은 앱 안에서 답변을 읽으므로 회신 주소가 없을 수 있다. 비회원 문의는 항상 채워진다.
    @Column(name = "email", length = 255)
    val email: String? = null,

    @Column(name = "subject", length = 100)
    val subject: String? = null,

    @Column(name = "content", nullable = false, length = 2000)
    val content: String,

    @Column(name = "ip_address", nullable = false, length = 45)
    val ipAddress: String,
) : EntityBase() {

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    var status: InquiryStatus = InquiryStatus.OPEN
        protected set

    @Column(name = "admin_memo", length = 1000)
    var adminMemo: String? = null
        protected set

    @Column(name = "closed_at")
    var closedAt: LocalDateTime? = null
        protected set

    @Column(name = "closed_by")
    var closedBy: Long? = null
        protected set

    @Column(name = "answer", length = 2000)
    var answer: String? = null
        protected set

    @Column(name = "answered_at")
    var answeredAt: LocalDateTime? = null
        protected set

    @Column(name = "answered_by")
    var answeredBy: Long? = null
        protected set

    /**
     * 답변을 저장하고, 이번 호출이 최초 답변이면 true 를 반환한다.
     * 최초 답변에만 알림을 보내야 하므로(오타 수정 재알림 방지) 호출자가 이 값으로 판단한다.
     */
    fun writeAnswer(answer: String, adminId: Long, now: LocalDateTime): Boolean {
        val firstAnswer = this.answer == null
        this.answer = answer
        this.answeredAt = now
        this.answeredBy = adminId
        return firstAnswer
    }

    fun changeStatus(status: InquiryStatus, memo: String?, adminId: Long, now: LocalDateTime) {
        val statusChanged = this.status != status
        this.status = status
        memo?.let { this.adminMemo = it.ifBlank { null } }
        if (statusChanged) {
            if (status == InquiryStatus.CLOSED) {
                closedAt = now
                closedBy = adminId
            } else {
                closedAt = null
                closedBy = null
            }
        }
    }
}
