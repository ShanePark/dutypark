package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.JpaRepository

interface FriendRelationRepository : JpaRepository<FriendRelation, Long> {

    fun findAllByMember(member: Member): List<FriendRelation>
    fun findByMemberAndFriend(member: Member, friend: Member): FriendRelation?

    fun deleteByMemberAndFriend(member: Member, friend: Member)

}