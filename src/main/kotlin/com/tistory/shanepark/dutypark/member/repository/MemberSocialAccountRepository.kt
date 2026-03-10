package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository

interface MemberSocialAccountRepository : JpaRepository<MemberSocialAccount, Long> {

    @EntityGraph(attributePaths = ["member"])
    fun findByProviderAndSocialId(provider: SsoType, socialId: String): MemberSocialAccount?

    @EntityGraph(attributePaths = ["member"])
    fun findByMemberAndProvider(member: Member, provider: SsoType): MemberSocialAccount?

    @EntityGraph(attributePaths = ["member"])
    fun findAllByMemberIdIn(memberIds: Collection<Long>): List<MemberSocialAccount>
}
