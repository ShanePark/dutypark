package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import org.assertj.core.api.Assertions.assertThat
import org.hibernate.SessionFactory
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

    @Autowired
    lateinit var blockService: BlockService

    @Autowired
    lateinit var sessionFactory: SessionFactory

    @Test
    fun `find All Friends test`() {
        val member1 = loginMember(TestData.member)
        val member2 = loginMember(TestData.member2)
        assertThat(friendService.findAllFriends(member1)).isEmpty()
        assertThat(friendService.findAllFriends(member2)).isEmpty()

        setFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        val friends = friendService.findAllFriends(member1)

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
        val viewer = TestData.member
        val loginMember = loginMember(viewer)
        val targetMember = TestData.member2

        TestData.team.admin = viewer
        teamRepository.save(TestData.team)
        targetMember.team = TestData.team
        memberRepository.save(targetMember)

        // Then no exception
        friendService.checkVisibility(login = loginMember, target = targetMember)
    }

    @Test
    fun `searchPossibleFriends should not load all friends and pending requests into memory`() {
        // Given: Create 20 friends and 10 pending requests for member1
        val member = TestData.member
        val loginMember = loginMember(member)

        val friends = mutableListOf<Member>()
        val pendingTargets = mutableListOf<Member>()

        // Create friends
        for (i in 1..20) {
            val friend = memberRepository.save(Member("friend$i", "friend$i@test.com", "pass"))
            friends.add(friend)
            setFriend(member, friend)
        }

        // Create pending friend requests
        for (i in 1..10) {
            val target = memberRepository.save(Member("pending$i", "pending$i@test.com", "pass"))
            pendingTargets.add(target)
            friendRequestRepository.save(FriendRequest(fromMember = member, toMember = target))
        }

        // Create potential friends (should appear in search result)
        val searchable = memberRepository.save(Member("searchable", "searchable@test.com", "pass"))

        em.flush()
        em.clear()

        // Enable statistics
        val statistics = sessionFactory.statistics
        statistics.isStatisticsEnabled = true
        statistics.clear()

        val page = Pageable.ofSize(10)
        val searchResult = friendService.searchPossibleFriends(loginMember, "searchable", page)

        // Expected: at most 2 queries (1 for search with subquery, 1 for count)
        val queryCount = statistics.prepareStatementCount

        // Verify functionality still works
        assertThat(searchResult.content).hasSize(1)
        assertThat(searchResult.content[0].name).isEqualTo("searchable")
        assertThat(searchResult.content).noneMatch { it.id in friends.map { f -> f.id } }
        assertThat(searchResult.content).noneMatch { it.id in pendingTargets.map { p -> p.id } }
        assertThat(searchResult.content).noneMatch { it.id == member.id }

        assertThat(queryCount)
            .describedAs("Query count should be at most 2 (search with subquery + count)")
            .isLessThanOrEqualTo(2)
    }

    @Test
    fun `isVisible is false when the target blocked the viewer`() {
        val viewer = TestData.member
        val target = TestData.member2
        separateTeams(viewer, target)
        updateVisibility(target, Visibility.PUBLIC)

        blockService.block(target.id!!, viewer.id!!)
        em.flush()
        em.clear()

        assertThat(friendService.isVisible(loginMember(viewer), target.id)).isFalse()
    }

    @Test
    fun `isVisible is false when the viewer blocked the target`() {
        val viewer = TestData.member
        val target = TestData.member2
        separateTeams(viewer, target)
        updateVisibility(target, Visibility.PUBLIC)

        blockService.block(viewer.id!!, target.id!!)
        em.flush()
        em.clear()

        assertThat(friendService.isVisible(loginMember(viewer), target.id)).isFalse()
    }

    @Test
    fun `isVisible stays true for blocked members of the same team`() {
        val viewer = TestData.member
        val target = TestData.member2
        updateVisibility(target, Visibility.PRIVATE)

        blockService.block(viewer.id!!, target.id!!)
        em.flush()
        em.clear()

        assertThat(friendService.isVisible(loginMember(viewer), target.id)).isTrue()
    }

    @Test
    fun `search Possible friends test - must not include members I blocked`() {
        val loginMember = loginMember(TestData.member)
        val target = TestData.member2

        blockService.block(TestData.member.id!!, target.id!!)
        em.flush()
        em.clear()

        val searchResult = friendService.searchPossibleFriends(loginMember, "", Pageable.ofSize(5))

        assertThat(searchResult.content).noneMatch { it.id == target.id }
    }

    @Test
    fun `search Possible friends test - must not include members who blocked me`() {
        val loginMember = loginMember(TestData.member)
        val target = TestData.member2

        blockService.block(target.id!!, TestData.member.id!!)
        em.flush()
        em.clear()

        val searchResult = friendService.searchPossibleFriends(loginMember, "", Pageable.ofSize(5))

        assertThat(searchResult.content).noneMatch { it.id == target.id }
    }

    @Test
    fun `send friend request fails when blocked`() {
        val target = TestData.member2
        blockService.block(target.id!!, TestData.member.id!!)
        em.flush()
        em.clear()

        val exception = assertThrows<BadRequestException> {
            friendService.sendFriendRequest(loginMember(TestData.member), target.id!!)
        }

        assertThat(exception.message).isEqualTo("friend.request.blocked")
    }

    @Test
    fun `send family request fails when blocked`() {
        val target = TestData.member2
        setFriend(TestData.member, target)
        blockService.block(TestData.member.id!!, target.id!!)
        em.flush()
        em.clear()

        val exception = assertThrows<BadRequestException> {
            friendService.sendFamilyRequest(loginMember(TestData.member), target.id!!)
        }

        assertThat(exception.message).isEqualTo("friend.request.blocked")
    }

    @Test
    fun `isVisible is false when a blocked member has no team`() {
        val viewer = TestData.member
        val target = TestData.member2
        clearTeams(viewer, target)
        updateVisibility(target, Visibility.PUBLIC)

        blockService.block(viewer.id!!, target.id!!)
        em.flush()
        em.clear()

        assertThat(friendService.isVisible(loginMember(viewer), target.id)).isFalse()
    }

    @Test
    fun `isVisible is false for a private calendar when neither member has a team`() {
        val viewer = TestData.member
        val target = TestData.member2
        clearTeams(viewer, target)
        updateVisibility(target, Visibility.PRIVATE)
        em.flush()
        em.clear()

        assertThat(friendService.isVisible(loginMember(viewer), target.id)).isFalse()
    }

    private fun clearTeams(vararg members: Member) {
        members.forEach {
            it.team = null
            memberRepository.save(it)
        }
    }

    private fun separateTeams(member1: Member, member2: Member) {
        member1.team = TestData.team
        member2.team = TestData.team2
        memberRepository.save(member1)
        memberRepository.save(member2)
    }

    private fun setFriend(
        member1: Member,
        member2: Member
    ) {
        friendRelationRepository.save(FriendRelation(member1, member2))
        friendRelationRepository.save(FriendRelation(member2, member1))
    }

}


