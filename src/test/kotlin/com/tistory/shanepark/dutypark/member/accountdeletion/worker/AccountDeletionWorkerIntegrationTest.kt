package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.FileSystemService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob
import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetMemberRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetTeamRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionExternalAccountRevoker
import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberConsent
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.entity.TeamManager
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import jakarta.persistence.EntityManager
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.mock
import org.mockito.kotlin.reset
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.util.unit.DataSize
import java.io.IOException
import java.io.UncheckedIOException
import java.nio.file.Files
import java.time.Clock
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.UUID

private val FIXED_NOW: Instant = Instant.parse("2026-08-12T03:00:00Z")
private const val STORAGE_ROOT = "/tmp/dutypark-account-deletion-worker-tests"

@DataJpaTest
@Import(
    AccountDeletionDatabaseCleaner::class,
    AccountDeletionFileCleaner::class,
    AccountDeletionJobCoordinator::class,
    FileSystemService::class,
    AccountDeletionWorkerIntegrationTest.TestConfig::class,
)
class AccountDeletionWorkerIntegrationTest {

    @Autowired
    private lateinit var em: EntityManager

    @Autowired
    private lateinit var jdbc: NamedParameterJdbcTemplate

    @Autowired
    private lateinit var databaseCleaner: AccountDeletionDatabaseCleaner

    @Autowired
    private lateinit var fileCleaner: AccountDeletionFileCleaner

    @Autowired
    private lateinit var pathResolver: StoragePathResolver

    @Autowired
    private lateinit var coordinator: AccountDeletionJobCoordinator

    @Autowired
    private lateinit var jobRepository: AccountDeletionJobRepository

    @Autowired
    private lateinit var targetMemberRepository: AccountDeletionTargetMemberRepository

    @Autowired
    private lateinit var targetTeamRepository: AccountDeletionTargetTeamRepository

    @Test
    fun `cleaners remove personal and solo team data while retaining and reassigning shared team content`() {
        val retainedTeam = persist(Team("ret-${shortId()}"))
        val soloTeam = persist(Team("solo-${shortId()}"))
        em.flush()

        val deleting = persist(member("deleting", retainedTeam))
        val survivor = persist(member("survivor", retainedTeam))
        val solo = persist(member("solo", soloTeam))
        em.flush()
        retainedTeam.changeAdmin(survivor)
        soloTeam.changeAdmin(solo)

        val deletingId = deleting.id!!
        val survivorId = survivor.id!!
        val soloId = solo.id!!
        val retainedTeamId = retainedTeam.id!!
        val soloTeamId = soloTeam.id!!

        persist(TeamManager(retainedTeam, deleting))
        persist(FriendRelation(deleting, survivor))
        persist(FriendRelation(survivor, deleting))
        persist(FriendRequest(deleting, survivor))
        persist(MemberManager(deleting, survivor, ManagerRole.MANAGER))
        persist(DDayEvent(deleting, "delete me", LocalDate.of(2026, 8, 12)))
        persist(MemberConsent(deleting, PolicyType.PRIVACY, "v1"))
        persist(MemberSocialAccount(deleting, SsoType.KAKAO, "kakao-$deletingId"))

        val deletingSchedule = persist(schedule(deleting, "deleting schedule"))
        deletingSchedule.addTag(survivor)
        val retainedSchedule = persist(schedule(survivor, "retained schedule"))
        retainedSchedule.addTag(deleting)

        val deletingTodo = persist(Todo(deleting, "deleting todo", "body", 0))
        deletingTodo.addTag(survivor)
        val retainedTodo = persist(Todo(survivor, "retained todo", "body", 0))
        retainedTodo.addTag(deleting)

        persist(
            Notification(
                member = deleting,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                referenceType = NotificationReferenceType.MEMBER,
                referenceId = survivorId.toString(),
                actorId = survivorId,
            )
        )
        persist(
            Notification(
                member = survivor,
                type = NotificationType.FRIEND_REQUEST_ACCEPTED,
                referenceType = NotificationReferenceType.MEMBER,
                referenceId = deletingId.toString(),
                actorId = deletingId,
            )
        )

        val refreshToken = persist(
            RefreshToken(
                member = deleting,
                validUntil = LocalDateTime.of(2026, 9, 12, 0, 0),
                remoteAddr = "127.0.0.1",
                userAgent = "account-deletion-test",
            )
        )
        persist(ApnsInstallation(refreshToken, "device-$deletingId"))

        val retainedTeamSchedule = persist(
            TeamSchedule(
                team = retainedTeam,
                createMember = deleting,
                updateMember = deleting,
                content = "retained team schedule",
                startDateTime = LocalDateTime.of(2026, 8, 12, 9, 0),
                endDateTime = LocalDateTime.of(2026, 8, 12, 10, 0),
                position = 0,
            )
        )
        val soloTeamSchedule = persist(
            TeamSchedule(
                team = soloTeam,
                createMember = solo,
                updateMember = solo,
                content = "solo team schedule",
                startDateTime = LocalDateTime.of(2026, 8, 12, 9, 0),
                endDateTime = LocalDateTime.of(2026, 8, 12, 10, 0),
                position = 0,
            )
        )
        val soloDutyType = persist(DutyType("DAY", 0, soloTeam, "#abcdef"))
        persist(Duty(LocalDate.of(2026, 8, 12), soloDutyType, solo, soloTeamId))
        persist(
            MemberDutyPattern(
                member = solo,
                team = soloTeam,
                dayTypes = mapOf(DayOfWeek.MONDAY to soloDutyType),
                holidayOff = true,
                effectiveFrom = LocalDate.of(2026, 8, 1),
            )
        )

        em.flush()

        val uploadSession = persist(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                ownerId = deletingId,
                expiresAt = FIXED_NOW.plusSeconds(3_600),
            )
        )
        persist(attachment(AttachmentContextType.SCHEDULE, deletingSchedule.id.toString(), deletingId))
        persist(attachment(AttachmentContextType.TODO, deletingTodo.id.toString(), deletingId))
        persist(attachment(AttachmentContextType.PROFILE, deletingId.toString(), deletingId))
        persist(attachment(AttachmentContextType.TEAM, retainedTeamId.toString(), deletingId))
        persist(attachment(AttachmentContextType.TEAM, soloTeamId.toString(), soloId))
        persist(
            attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                createdBy = deletingId,
                uploadSessionId = uploadSession.id,
            )
        )
        em.flush()
        em.clear()

        val deletingScheduleDir = createContextFile(AttachmentContextType.SCHEDULE, deletingSchedule.id.toString())
        val deletingTodoDir = createContextFile(AttachmentContextType.TODO, deletingTodo.id.toString())
        val profileDir = createContextFile(AttachmentContextType.PROFILE, deletingId.toString())
        val retainedTeamDir = createContextFile(AttachmentContextType.TEAM, retainedTeamId.toString())
        val soloTeamDir = createContextFile(AttachmentContextType.TEAM, soloTeamId.toString())
        val temporaryDir = pathResolver.resolveTemporaryDirectory(uploadSession.id)
        Files.createDirectories(temporaryDir)
        Files.writeString(temporaryDir.resolve("temporary.txt"), "delete")

        val memberIds = listOf(deletingId, soloId)
        val teamIds = listOf(soloTeamId)

        fileCleaner.deleteFiles(memberIds, teamIds)

        assertThat(deletingScheduleDir).doesNotExist()
        assertThat(deletingTodoDir).doesNotExist()
        assertThat(profileDir).doesNotExist()
        assertThat(soloTeamDir).doesNotExist()
        assertThat(temporaryDir).doesNotExist()
        assertThat(retainedTeamDir).exists()

        databaseCleaner.clean(memberIds, teamIds)
        databaseCleaner.clean(memberIds, teamIds)
        fileCleaner.deleteFiles(memberIds, teamIds)

        assertThat(count("member", "id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("member", "id = :id", mapOf("id" to survivorId))).isOne()
        assertThat(count("team", "id = :id", mapOf("id" to soloTeamId))).isZero()
        assertThat(count("team", "id = :id", mapOf("id" to retainedTeamId))).isOne()
        assertThat(count("schedule", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("todo", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("schedule_tags", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("todo_tags", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("friends", "member_id in (:ids) or friend_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("friend_requests", "from_member_id in (:ids) or to_member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("member_manager", "manager_id in (:ids) or managed_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("team_managers", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("notifications", "member_id in (:ids) or actor_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("d_day_event", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("member_consent", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("member_social_account", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("refresh_token", "member_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("apns_installation", "device_token = :token", mapOf("token" to "device-$deletingId"))).isZero()
        assertThat(count("attachment_upload_session", "owner_id in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("attachment", "context_type <> 'TEAM' and created_by in (:ids)", mapOf("ids" to memberIds))).isZero()
        assertThat(count("team_schedule", "id = :id", mapOf("id" to soloTeamSchedule.id.toString()))).isZero()
        assertThat(count("duty", "team_id = :id", mapOf("id" to soloTeamId))).isZero()
        assertThat(count("duty_type", "team_id = :id", mapOf("id" to soloTeamId))).isZero()
        assertThat(count("member_duty_pattern", "team_id = :id", mapOf("id" to soloTeamId))).isZero()

        assertThat(longValue("select create_member_id from team_schedule where id = :id", mapOf("id" to retainedTeamSchedule.id.toString())))
            .isEqualTo(survivorId)
        assertThat(longValue("select update_member_id from team_schedule where id = :id", mapOf("id" to retainedTeamSchedule.id.toString())))
            .isEqualTo(survivorId)
        assertThat(longValue("select created_by from attachment where context_type = 'TEAM' and context_id = :id", mapOf("id" to retainedTeamId.toString())))
            .isEqualTo(survivorId)

        Files.deleteIfExists(retainedTeamDir.resolve("file.txt"))
        Files.deleteIfExists(retainedTeamDir)
    }

    @Test
    fun `worker retries after file cleanup failure and completes idempotently`() {
        val fileCleanerMock = mock<AccountDeletionFileCleaner>()
        val databaseCleanerMock = mock<AccountDeletionDatabaseCleaner>()
        val revoker = mock<AccountDeletionExternalAccountRevoker>()
        val worker = AccountDeletionWorker(
            coordinator = coordinator,
            targetMemberRepository = targetMemberRepository,
            targetTeamRepository = targetTeamRepository,
            externalAccountRevoker = revoker,
            fileCleaner = fileCleanerMock,
            databaseCleaner = databaseCleanerMock,
        )
        val memberIds = listOf(101L)
        val teamIds = listOf(201L)
        val job = newJob(memberIds, teamIds)
        doThrow(UncheckedIOException(IOException("simulated deletion failure")))
            .whenever(fileCleanerMock).deleteFiles(memberIds, teamIds)

        worker.processPendingJobs()

        val retrying = jobRepository.findById(job.id!!).orElseThrow()
        assertThat(retrying.status).isEqualTo(AccountDeletionJobStatus.RETRY_WAIT)
        assertThat(retrying.attemptCount).isOne()
        assertThat(retrying.nextAttemptAt).isEqualTo(FIXED_NOW.plusSeconds(60))
        assertThat(retrying.lastError).contains("UncheckedIOException")
        verify(databaseCleanerMock, org.mockito.kotlin.never()).clean(memberIds, teamIds)

        jdbc.update(
            "update account_deletion_job set next_attempt_at = :now where id = :id",
            mapOf("now" to FIXED_NOW, "id" to job.id!!),
        )
        reset(fileCleanerMock)

        worker.processPendingJobs()
        worker.processPendingJobs()

        val completed = jobRepository.findById(job.id!!).orElseThrow()
        assertThat(completed.status).isEqualTo(AccountDeletionJobStatus.COMPLETED)
        assertThat(completed.attemptCount).isEqualTo(2)
        assertThat(completed.completedAt).isEqualTo(FIXED_NOW)
        verify(fileCleanerMock).deleteFiles(memberIds, teamIds)
        verify(databaseCleanerMock).clean(memberIds, teamIds)
    }

    @Test
    fun `coordinator reclaims a stale processing job`() {
        val job = newJob(listOf(301L), emptyList())
        jdbc.update(
            """
            update account_deletion_job
            set status = 'PROCESSING', attempt_count = 1, locked_at = :lockedAt
            where id = :id
            """.trimIndent(),
            mapOf("lockedAt" to FIXED_NOW.minusSeconds(16 * 60), "id" to job.id!!),
        )
        em.clear()

        assertThat(coordinator.claimNext()).isEqualTo(job.id)

        val reclaimed = jobRepository.findById(job.id!!).orElseThrow()
        assertThat(reclaimed.status).isEqualTo(AccountDeletionJobStatus.PROCESSING)
        assertThat(reclaimed.attemptCount).isEqualTo(2)
        assertThat(reclaimed.lockedAt).isEqualTo(FIXED_NOW)
    }

    private fun newJob(memberIds: List<Long>, teamIds: List<Long>): AccountDeletionJob {
        val job = AccountDeletionJob(
            rootMemberId = memberIds.first(),
            deleteTeamId = teamIds.singleOrNull(),
            nextAttemptAt = FIXED_NOW,
            createdAt = FIXED_NOW,
        )
        memberIds.forEach(job::addTargetMember)
        teamIds.forEach(job::addTargetTeam)
        return jobRepository.saveAndFlush(job)
    }

    private fun member(prefix: String, team: Team): Member = Member(
        name = prefix.take(10),
        email = "$prefix-${UUID.randomUUID()}@duty.park",
        password = "encoded-password",
    ).also { it.team = team }

    private fun shortId(): String = UUID.randomUUID().toString().take(8)

    private fun schedule(member: Member, content: String) = Schedule(
        member = member,
        content = content,
        startDateTime = LocalDateTime.of(2026, 8, 12, 9, 0),
        endDateTime = LocalDateTime.of(2026, 8, 12, 10, 0),
    )

    private fun attachment(
        contextType: AttachmentContextType,
        contextId: String?,
        createdBy: Long,
        uploadSessionId: UUID? = null,
    ) = Attachment(
        contextType = contextType,
        contextId = contextId,
        uploadSessionId = uploadSessionId,
        originalFilename = "file.txt",
        storedFilename = "${UUID.randomUUID()}.txt",
        contentType = "text/plain",
        size = 6,
        storagePath = "test",
        createdBy = createdBy,
    )

    private fun createContextFile(type: AttachmentContextType, contextId: String) =
        pathResolver.resolveContextDirectory(type, contextId).also { directory ->
            Files.createDirectories(directory)
            Files.writeString(directory.resolve("file.txt"), "delete")
        }

    private fun count(table: String, predicate: String, params: Map<String, Any>): Int =
        jdbc.queryForObject("select count(*) from $table where $predicate", params, Int::class.java)!!

    private fun longValue(sql: String, params: Map<String, Any>): Long =
        jdbc.queryForObject(sql, params, Long::class.javaObjectType)!!

    private fun <T : Any> persist(entity: T): T {
        em.persist(entity)
        return entity
    }

    @TestConfiguration
    class TestConfig {
        @Bean
        @Primary
        fun fixedClock(): Clock = Clock.fixed(FIXED_NOW, ZoneOffset.UTC)

        @Bean
        fun testStoragePathResolver(): StoragePathResolver = StoragePathResolver(
            StorageProperties(
                root = STORAGE_ROOT,
                maxFileSize = DataSize.ofMegabytes(50),
                thumbnail = StorageProperties.ThumbnailProperties(maxSide = 200),
                sessionExpirationHours = 24,
            )
        )
    }
}
