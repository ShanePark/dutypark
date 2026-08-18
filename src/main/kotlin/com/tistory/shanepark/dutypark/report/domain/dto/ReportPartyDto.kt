package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus

/**
 * A member still involved in a report. Null once that member deleted the account,
 * in which case the name snapshots kept on the report stay authoritative.
 */
data class ReportPartyDto(
    val id: Long,
    val name: String,
    val status: MemberStatus,
) {
    companion object {
        fun of(member: Member?): ReportPartyDto? {
            return member?.let {
                ReportPartyDto(
                    id = it.id!!,
                    name = it.name,
                    status = it.status,
                )
            }
        }
    }
}
