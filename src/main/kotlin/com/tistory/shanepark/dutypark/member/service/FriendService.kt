package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class FriendService(
    private val friendRelationRepository: FriendRelationRepository,
) {

    @Transactional(readOnly = true)
    fun findAllFriends(member: Member): List<Member> {
        return friendRelationRepository.findAllByMember(member).map { it.friend }
    }

    fun addFriend(member1: Member, member2: Member) {
        if (isFriend(member1, member2))
            throw IllegalArgumentException("Already friend")

        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

    fun unfriend(member1: Member, member2: Member) {
        val isFriend = isFriend(member1, member2)
        if (!isFriend)
            throw IllegalArgumentException("Not friend")

        friendRelationRepository.deleteByMemberAndFriend(member1, member2)
        friendRelationRepository.deleteByMemberAndFriend(member2, member1)
    }

    fun isFriend(member1: Member, member2: Member): Boolean {
        friendRelationRepository.findByMemberAndFriend(member1, member2)
            ?.let { return true }
            .run { return false }
    }

}
