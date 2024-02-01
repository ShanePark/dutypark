package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class FriendServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var friendService: FriendService

    @Test
    fun `Add friend test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        Assertions.assertThat(friendService.isFriend(member1, member2)).isFalse

        // When
        friendService.addFriend(member1, member2)

        // Then
        Assertions.assertThat(friendService.isFriend(member1, member2)).isTrue
    }

    @Test
    fun `find All Friends test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        Assertions.assertThat(friendService.findAllFriends(member1)).isEmpty()
        Assertions.assertThat(friendService.findAllFriends(member2)).isEmpty()

        friendService.addFriend(member1, member2)

        // When
        val friends = friendService.findAllFriends(member1)

        // Then
        Assertions.assertThat(friends).hasSize(1)
        Assertions.assertThat(friends[0].id).isEqualTo(member2.id)
        Assertions.assertThat(friendService.findAllFriends(member2)).hasSize(1)
    }

    @Test
    fun `Unfriend test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        friendService.addFriend(member1, member2)
        Assertions.assertThat(friendService.isFriend(member1, member2)).isTrue

        // When
        friendService.unfriend(member1, member2)

        // Then
        Assertions.assertThat(friendService.isFriend(member1, member2)).isFalse
    }

    @Test
    fun `isFriend test`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        Assertions.assertThat(friendService.isFriend(member1, member2)).isFalse

        friendService.addFriend(member1, member2)

        // When
        val isFriend = friendService.isFriend(member1, member2)

        // Then
        Assertions.assertThat(isFriend).isTrue
    }

}
