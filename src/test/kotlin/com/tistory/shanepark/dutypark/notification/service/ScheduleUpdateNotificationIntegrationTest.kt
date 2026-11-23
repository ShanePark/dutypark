package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.ForbiddenException
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleUpdatedPayload
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import com.tistory.shanepark.dutypark.schedule.service.ScheduleRevisionService
import com.tistory.shanepark.dutypark.schedule.event.ScheduleUpdatedEvent
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.ApplicationEventPublisher
import org.springframework.data.domain.PageRequest
import tools.jackson.databind.json.JsonMapper
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.TransactionDefinition
import org.springframework.transaction.support.TransactionTemplate
import java.time.LocalDateTime
import java.util.UUID

class ScheduleUpdateNotificationIntegrationTest : DutyparkIntegrationTest() {
    @Autowired lateinit var scheduleService: ScheduleService
    @Autowired lateinit var notifications: NotificationRepository
    @Autowired lateinit var codec: NotificationPayloadCodec
    @Autowired lateinit var changes: ScheduleNotificationChangesService
    @Autowired lateinit var revisionService: ScheduleRevisionService
    @Autowired lateinit var eventPublisher: ApplicationEventPublisher
    @Autowired lateinit var transactionManager: PlatformTransactionManager
    @Autowired lateinit var schedules: ScheduleRepository
    @Autowired lateinit var notificationService: NotificationService
    @Autowired lateinit var jsonMapper: JsonMapper
    @Autowired lateinit var blockService: BlockService

    @Test
    fun `inline schedule title comes from the notified version after later title changes`() {
        val owner = TestData.member
        val tagged = TestData.member2
        makeThemFriend(owner, tagged)
        val initial = request(owner, listOf(tagged))
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
        scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, description = "Body changed"))
        val bodyNotice = updates().single()

        scheduleService.updateSchedule(loginMember(owner), initial.copy(
            id = schedule.id, description = "Body changed", content = "Later title",
        ))
        val earlier = notificationService.getUnreadNotifications(tagged.id!!).single { it.id == bodyNotice.id }
        val inline = jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(earlier).path("scheduleChanges")
        assertThat(inline.path("scheduleTitle").asText()).isEqualTo("Meeting")
        assertThat(inline.path("title").isNull).isTrue()
        val detail = jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(changes.getChanges(loginMember(tagged), bodyNotice.id))
        assertThat(detail.path("scheduleTitle").asText()).isEqualTo("Meeting")
        val titleNotice = notificationService.getUnreadNotifications(tagged.id!!).single { it.id != bodyNotice.id && it.type == NotificationType.SCHEDULE_UPDATED }
        assertThat(jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(titleNotice).path("scheduleChanges").path("scheduleTitle").asText()).isEqualTo("Later title")
        assertThat(jsonMapper.writeValueAsString(NotificationDto.of(bodyNotice, decoded(bodyNotice))))
            .doesNotContain("Meeting", "Later title", "Body changed")
        assertThrows<NoSuchElementException> { changes.getChanges(loginMember(owner), bodyNotice.id) }
        scheduleService.untagSelf(loginMember(tagged), schedule.id)
        assertThat(notificationService.getNotifications(tagged.id!!, PageRequest.of(0, 20)).content)
            .allMatch { it.scheduleChanges == null }
    }

    @Test
    fun `blocking a delegated actor hides inline changes while retaining the other owner's tag`() {
        val owner = TestData.member
        val manager = TestData.member2
        val tagged = createParticipant("BlockedC")
        listOf(manager, tagged).forEach { makeThemFriend(owner, it) }
        memberManagerRepository.save(MemberManager(manager, owner, ManagerRole.MANAGER))
        val initial = request(owner, listOf(manager, tagged))
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
        scheduleService.updateSchedule(loginMember(manager), initial.copy(id = schedule.id, description = "Private changed text"))
        val notice = updates().single { it.member.id == tagged.id }
        assertThat(notificationService.getUnreadNotifications(tagged.id!!).single { it.id == notice.id }.scheduleChanges).isNotNull()
        blockService.block(tagged.id!!, manager.id!!)
        val afterBlock = notificationService.getUnreadNotifications(tagged.id!!).single { it.id == notice.id }
        assertThat(afterBlock.scheduleChanges).isNull()
        assertThat(jsonMapper.writeValueAsString(afterBlock)).doesNotContain("Private changed text")
    }

    @Test
    fun `authenticated notification reads include pinned changes inline but push and revoked reads omit them`() {
        val owner = TestData.member
        val tagged = TestData.member2
        makeThemFriend(owner, tagged)
        val initial = request(owner, listOf(tagged))
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
        scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, description = "New body"))
        val notice = updates().single()

        val unread = notificationService.getUnreadNotifications(tagged.id!!).single { it.id == notice.id }
        val unreadJson = jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(unread)
        assertThat(unreadJson.path("scheduleChanges").path("description").path("before").asText()).isEqualTo("Initial description")
        assertThat(unreadJson.path("scheduleChanges").path("description").path("after").asText()).isEqualTo("New body")
        assertThat(unreadJson.path("scheduleChanges").path("title").isNull).isTrue()
        val paged = notificationService.getNotifications(tagged.id!!, PageRequest.of(0, 20)).content.single { it.id == notice.id }
        assertThat(jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(paged).path("scheduleChanges")).isEqualTo(unreadJson.path("scheduleChanges"))
        val read = notificationService.markAsRead(tagged.id!!, notice.id)
        assertThat(jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(read).path("scheduleChanges")).isEqualTo(unreadJson.path("scheduleChanges"))

        val push = NotificationDto.of(notice, decoded(notice))
        assertThat(jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(push).path("scheduleChanges").isNull).isTrue()
        assertThat(jsonMapper.writeValueAsString(push)).doesNotContain("Initial description", "New body")
        scheduleService.untagSelf(loginMember(tagged), schedule.id)
        val revoked = notificationService.getNotifications(tagged.id!!, PageRequest.of(0, 20)).content.single { it.id == notice.id }
        assertThat(jsonMapper.valueToTree<tools.jackson.databind.JsonNode>(revoked).path("scheduleChanges").isNull).isTrue()
        assertThat(jsonMapper.writeValueAsString(revoked)).doesNotContain("Initial description", "New body")
        assertThat(notificationService.getNotifications(owner.id!!, PageRequest.of(0, 20)).content).noneMatch { it.id == notice.id }
        scheduleService.deleteSchedule(loginMember(owner), schedule.id)
        em.flush()
        assertThat(notificationService.getNotifications(tagged.id!!, PageRequest.of(0, 20)).content).hasSize(1)
    }

    @Test
    fun `rolling back the schedule edit also rolls back its notification records`() {
        var scheduleId: UUID? = null
        var notificationId: UUID? = null
        TransactionTemplate(transactionManager).apply {
            propagationBehavior = TransactionDefinition.PROPAGATION_REQUIRES_NEW
        }.executeWithoutResult { transaction ->
            val owner = createParticipant("rbOwner")
            val tagged = createParticipant("rbTagged")
            makeThemFriend(owner, tagged)
            val initial = request(owner, listOf(tagged))
            val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
            scheduleId = schedule.id
            scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, content = "Rolled back title"))
            val notification = updates().single { it.referenceId == schedule.id.toString() }
            notificationId = notification.id
            em.flush()
            transaction.setRollbackOnly()
        }
        assertThat(schedules.findById(scheduleId!!)).isEmpty()
        assertThat(notifications.findById(notificationId!!)).isEmpty()
    }

    @Test
    fun `owner and manager changes notify exactly the other retained participants and preserve earlier differences`() {
        val owner = TestData.member
        val manager = TestData.member2
        val c = createParticipant("C")
        val d = createParticipant("D")
        val e = createParticipant("E")
        listOf(manager, c, d, e).forEach { makeThemFriend(owner, it) }
        memberManagerRepository.save(MemberManager(manager, owner, ManagerRole.MANAGER))
        val initial = request(owner, listOf(manager, c, d))
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule

        scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, content = "Changed title"))
        val firstNotifications = updates()
        assertThat(firstNotifications.map { it.member.id }).containsExactlyInAnyOrder(manager.id, c.id, d.id)
        assertThat(firstNotifications.map { it.actorId }).containsOnly(owner.id)
        eventPublisher.publishEvent(ScheduleUpdatedEvent(
            schedule.id, owner.id!!, owner.id!!, schedule.version,
            revisionService.snapshot(revisionService.findRevision(schedule, schedule.version - 1)),
            revisionService.snapshot(revisionService.findRevision(schedule, schedule.version)),
        ))
        assertThat(updates()).hasSize(firstNotifications.size)
        val managerNotice = firstNotifications.single { it.member.id == manager.id }
        val firstChanges = changes.getChanges(loginMember(manager), managerNotice.id)
        assertThat(firstChanges.title?.before).isEqualTo("Meeting")
        assertThat(firstChanges.title?.after).isEqualTo("Changed title")
        assertThat(firstChanges.description).isNull()
        assertThat(firstChanges.time).isNull()

        scheduleService.updateSchedule(loginMember(manager), initial.copy(
            id = schedule.id, content = "Changed title", description = "Updated description",
            tagFriendIds = listOf(manager.id!!, c.id!!, d.id!!),
        ))
        val secondNotifications = updates().filter { it.id !in firstNotifications.map { it.id } }
        assertThat(secondNotifications.map { it.member.id }).containsExactlyInAnyOrder(owner.id, c.id, d.id)
        assertThat(secondNotifications.map { it.actorId }).containsOnly(manager.id)
        val payload = decoded(secondNotifications.first())
        assertThat(payload.changedFields).containsExactly("DESCRIPTION")
        assertThat(secondNotifications.first().payloadJson).doesNotContain("Updated description", "Initial description", "Meeting")
        assertThat(changes.getChanges(loginMember(manager), managerNotice.id)).isEqualTo(firstChanges)

        val beforeNoOp = updates().size
        scheduleService.updateSchedule(loginMember(manager), initial.copy(
            id = schedule.id, content = "Changed title", description = "Updated description",
        ))
        assertThat(updates()).hasSize(beforeNoOp)

        scheduleService.updateSchedule(loginMember(owner), initial.copy(
            id = schedule.id, content = "Changed title", description = "Updated again",
            startDateTime = initial.startDateTime.plusHours(2), endDateTime = initial.endDateTime.plusHours(2),
            tagFriendIds = listOf(manager.id!!, c.id!!, e.id!!),
        ))
        val lastVersion = schedule.version
        val latest = updates().filter { decoded(it).scheduleVersion == lastVersion }
        assertThat(latest.map { it.member.id }).containsExactlyInAnyOrder(manager.id, c.id)
        val latestChanges = changes.getChanges(loginMember(manager), latest.single { it.member.id == manager.id }.id)
        assertThat(latestChanges.changedFields).containsExactly("DESCRIPTION", "TIME")
        assertThat(latestChanges.time?.before?.startDateTime).isEqualTo(initial.startDateTime)
        assertThat(latestChanges.time?.after?.startDateTime).isEqualTo(initial.startDateTime.plusHours(2))
        assertThrows<ForbiddenException> {
            changes.getChanges(loginMember(d), firstNotifications.single { it.member.id == d.id }.id)
        }
        assertThrows<NoSuchElementException> { changes.getChanges(loginMember(e), managerNotice.id) }
        scheduleService.deleteSchedule(loginMember(owner), schedule.id)
        em.flush()
        assertThrows<NoSuchElementException> { changes.getChanges(loginMember(manager), managerNotice.id) }
    }

    @Test
    fun `an unshared schedule and a tag-only change do not create update notifications`() {
        val owner = TestData.member
        val initial = request(owner, emptyList())
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
        scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, description = "New"))
        assertThat(updates()).isEmpty()
        makeThemFriend(owner, TestData.member2)
        scheduleService.updateSchedule(loginMember(owner), initial.copy(
            id = schedule.id, description = "New", tagFriendIds = listOf(TestData.member2.id!!),
        ))
        assertThat(updates()).isEmpty()
    }

    private fun updates() = notifications.findAll().filter { it.type == NotificationType.SCHEDULE_UPDATED }

    private fun decoded(notification: Notification) =
        ((codec.safeDeserialize(notification.type, notification.payloadVersion, notification.payloadJson)
            as NotificationPayloadDecodeResult.Success).payload as ScheduleUpdatedPayload)

    private fun createParticipant(name: String): Member =
        memberRepository.save(Member(name, "$name@notification.test", "password"))

    private fun request(owner: Member, tags: List<Member>): ScheduleSaveDto {
        val start = LocalDateTime.of(2026, 11, 23, 14, 0)
        return ScheduleSaveDto(
            memberId = owner.id!!, content = "Meeting", description = "Initial description",
            startDateTime = start, endDateTime = start.plusHours(1),
            tagFriendIds = tags.map { it.id!! }, aiTimeParsingRequested = false,
        )
    }
}
