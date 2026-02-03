package com.tistory.shanepark.dutypark.schedule.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager
import java.time.LocalDateTime
import java.util.UUID

@DataJpaTest
class ScheduleRepositoryTest {

    @Autowired
    private lateinit var repository: ScheduleRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    private var owner1Id: Long = 0
    private var owner2Id: Long = 0
    private var taggedMemberId: Long = 0
    private var otherTagMemberId: Long = 0
    private lateinit var schedule1Id: UUID
    private lateinit var schedule2Id: UUID

    @BeforeEach
    fun setUp() {
        val owner1 = entityManager.persist(Member(name = "owner1"))
        val owner2 = entityManager.persist(Member(name = "owner2"))
        val taggedMember = entityManager.persist(Member(name = "tagged"))
        val otherTagMember = entityManager.persist(Member(name = "other"))

        owner1Id = owner1.id!!
        owner2Id = owner2.id!!
        taggedMemberId = taggedMember.id!!
        otherTagMemberId = otherTagMember.id!!

        val start = LocalDateTime.of(2025, 1, 1, 9, 0)
        val end = LocalDateTime.of(2025, 1, 1, 10, 0)

        val schedule1 = Schedule(
            member = owner1,
            content = "schedule1",
            description = "",
            startDateTime = start,
            endDateTime = end,
            visibility = Visibility.PUBLIC
        )
        schedule1.addTag(taggedMember)
        schedule1.addTag(otherTagMember)
        entityManager.persist(schedule1)

        val schedule2 = Schedule(
            member = owner2,
            content = "schedule2",
            description = "",
            startDateTime = start,
            endDateTime = end,
            visibility = Visibility.PUBLIC
        )
        schedule2.addTag(taggedMember)
        entityManager.persist(schedule2)

        val scheduleOutOfRange = Schedule(
            member = owner2,
            content = "outOfRange",
            description = "",
            startDateTime = start.plusDays(2),
            endDateTime = end.plusDays(2),
            visibility = Visibility.PUBLIC
        )
        entityManager.persist(scheduleOutOfRange)

        schedule1Id = schedule1.id
        schedule2Id = schedule2.id

        entityManager.flush()
        entityManager.clear()
    }

    @Test
    fun `findSchedulesOfMembersRangeIn returns schedules for multiple members`() {
        val owner1 = requireNotNull(entityManager.find(Member::class.java, owner1Id))
        val owner2 = requireNotNull(entityManager.find(Member::class.java, owner2Id))
        val start = LocalDateTime.of(2025, 1, 1, 0, 0)
        val end = LocalDateTime.of(2025, 1, 1, 23, 59, 59)

        val result = repository.findSchedulesOfMembersRangeIn(
            members = listOf(owner1, owner2),
            start = start,
            end = end,
            visibilities = Visibility.all()
        )

        assertThat(result.map { it.id }).containsExactlyInAnyOrder(schedule1Id, schedule2Id)
    }

    @Test
    fun `findTaggedSchedulesOfMembersRangeIn returns schedules with full tag list`() {
        val taggedMember = requireNotNull(entityManager.find(Member::class.java, taggedMemberId))
        val start = LocalDateTime.of(2025, 1, 1, 0, 0)
        val end = LocalDateTime.of(2025, 1, 1, 23, 59, 59)

        val result = repository.findTaggedSchedulesOfMembersRangeIn(
            taggedMembers = listOf(taggedMember),
            start = start,
            end = end,
            visibilities = Visibility.all()
        )

        assertThat(result.map { it.id }).containsExactlyInAnyOrder(schedule1Id, schedule2Id)

        val schedule1 = result.first { it.id == schedule1Id }
        val tagMemberIds = schedule1.tags.map { it.member.id }
        assertThat(tagMemberIds).containsExactlyInAnyOrder(taggedMemberId, otherTagMemberId)
    }
}
