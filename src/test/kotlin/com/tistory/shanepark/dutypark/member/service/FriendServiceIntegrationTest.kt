package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable

/**
 * Integration tests for FriendService that require complex DB interactions.
 * Unit tests for simpler business logic are in FriendServiceUnitTest.
 */

class FriendServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var friendService: FriendService

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Test
    fun `find All Friends test`() {
        // Given
        val member1 = loginMember(TestData.member)
        val member2 = loginMember(TestData.member2)
        assertThat(friendService.findAllFriends(member1)).isEmpty()
        assertThat(friendService.findAllFriends(member2)).isEmpty()

        setFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        // When
        val friends = friendService.findAllFriends(member1)

        // Then
        assertThat(friends).hasSize(1)
        assertThat(friends[0].id).isEqualTo(member2.id)
        assertThat(friendService.findAllFriends(member2)).hasSize(1)
    }

    @Test
    fun `search Possible friends test - must not include self`() {
        val loginMember = loginMember(TestData.member)

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult.content).noneMatch { it.id == loginMember.id }
    }

    @Test
    fun `search Possible friends test - must not include friends`() {
        val loginMember = loginMember(TestData.member)
        val friend = TestData.member2
        setFriend(TestData.member, friend)

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult.content).noneMatch { it.id == friend.id }
    }

    @Test
    fun `search Possible friends test - must not include pending requests`() {
        val loginMember = loginMember(TestData.member)
        val taget = TestData.member2
        friendRequestRepository.save(FriendRequest(fromMember = TestData.member, toMember = taget))

        val page = Pageable.ofSize(5)
        val searchResult = friendService.searchPossibleFriends(loginMember, "", page)

        assertThat(searchResult).isNotEmpty
        assertThat(searchResult.content).noneMatch { it.id == taget.id }
    }

    @Test
    fun `check visibility can't pass if the setting is private and login is not his manager and they are not in same team`() {
        val loginMember = loginMember(TestData.member)
        val targetMember = TestData.member2
        targetMember.calendarVisibility = Visibility.PRIVATE

        TestData.member.team = TestData.team
        targetMember.team = TestData.team2
        memberRepository.save(TestData.member)
        memberRepository.save(targetMember)

        assertThrows<AuthException> {
            friendService.checkVisibility(loginMember, targetMember)
        }
    }

    @Test
    fun `check visibility pass even if the setting is private, when login is his manager`() {
        // Given
        val viewer = TestData.member
        val loginMember = loginMember(viewer)
        val targetMember = TestData.member2

        // When
        TestData.team.admin = viewer
        teamRepository.save(TestData.team)
        targetMember.team = TestData.team
        memberRepository.save(targetMember)

        // Then no exception
        friendService.checkVisibility(login = loginMember, target = targetMember)
    }

    private fun setFriend(
        member1: Member,
        member2: Member
    ) {
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

}


