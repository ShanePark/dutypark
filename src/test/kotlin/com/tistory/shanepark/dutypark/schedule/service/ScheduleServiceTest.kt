package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.attachment.service.FileSystemService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingQueueManager
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.*
import org.springframework.context.ApplicationEventPublisher
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime
import java.util.*

class ScheduleServiceTest {

    private lateinit var scheduleService: ScheduleService
    private lateinit var scheduleRepository: ScheduleRepository
    private lateinit var memberRepository: MemberRepository
    private lateinit var friendService: FriendService
    private lateinit var scheduleTimeParsingQueueManager: ScheduleTimeParsingQueueManager
    private lateinit var schedulePermissionService: SchedulePermissionService
    private lateinit var attachmentRepository: AttachmentRepository
    private lateinit var attachmentService: AttachmentService
    private lateinit var fileSystemService: FileSystemService
    private lateinit var pathResolver: StoragePathResolver
    private lateinit var eventPublisher: ApplicationEventPublisher

    private lateinit var member: Member
    private lateinit var member2: Member
    private lateinit var loginMember: LoginMember
    private lateinit var loginMember2: LoginMember

    @BeforeEach
    fun setUp() {
        scheduleRepository = mock()
        memberRepository = mock()
        friendService = mock()
        scheduleTimeParsingQueueManager = mock()
        schedulePermissionService = mock()
        attachmentRepository = mock()
        attachmentService = mock()
        fileSystemService = mock()
        pathResolver = mock()
        eventPublisher = mock()

        scheduleService = ScheduleService(
            scheduleRepository = scheduleRepository,
            memberRepository = memberRepository,
            friendService = friendService,
            scheduleTimeParsingQueueManager = scheduleTimeParsingQueueManager,
            schedulePermissionService = schedulePermissionService,
            attachmentRepository = attachmentRepository,
            attachmentService = attachmentService,
            fileSystemService = fileSystemService,
            pathResolver = pathResolver,
            eventPublisher = eventPublisher
        )

        member = Member(name = "testMember", email = "test@test.com", password = "1234")
        ReflectionTestUtils.setField(member, "id", 1L)

        member2 = Member(name = "testMember2", email = "test2@test.com", password = "1234")
        ReflectionTestUtils.setField(member2, "id", 2L)

        loginMember = LoginMember(id = member.id!!, email = member.email, name = member.name)
        loginMember2 = LoginMember(id = member2.id!!, email = member2.email, name = member2.name)
    }

    @Test
    fun `Create schedule success test`() {
        // given
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = member.id!!,
            content = "schedule1",
            description = "description1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(scheduleRepository.findMaxPosition(eq(member), any())).thenReturn(-1)
        whenever(scheduleRepository.save(any<Schedule>())).thenAnswer { invocation ->
            val schedule = invocation.getArgument<Schedule>(0)
            ReflectionTestUtils.setField(schedule, "id", UUID.randomUUID())
            schedule
        }

        // When
        val createdSchedule = scheduleService.createSchedule(loginMember, scheduleSaveDto)

        // Then
        assertThat(createdSchedule).isNotNull
        assertThat(createdSchedule.id).isNotNull
        assertThat(createdSchedule.content).isEqualTo(scheduleSaveDto.content)
        assertThat(createdSchedule.description).isEqualTo(scheduleSaveDto.description)
        assertThat(createdSchedule.startDateTime).isEqualTo(scheduleSaveDto.startDateTime)
        assertThat(createdSchedule.endDateTime).isEqualTo(scheduleSaveDto.endDateTime)
        assertThat(createdSchedule.position).isEqualTo(0)

        verify(schedulePermissionService).checkScheduleWriteAuthority(loginMember, member)
        verify(scheduleRepository).save(any<Schedule>())
        verify(scheduleTimeParsingQueueManager).addTask(any<Schedule>())
    }

    @Test
    fun `can't create other member's schedule`() {
        // given
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = member2.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        whenever(memberRepository.findById(member2.id!!)).thenReturn(Optional.of(member2))
        whenever(schedulePermissionService.checkScheduleWriteAuthority(loginMember, member2))
            .thenThrow(AuthException("login member doesn't have permission"))

        // When & Then
        assertThrows<AuthException> {
            scheduleService.createSchedule(loginMember, scheduleSaveDto)
        }
    }

    @Test
    fun `update Schedule Test`() {
        // given
        val scheduleId = UUID.randomUUID()
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            description = "description1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        ReflectionTestUtils.setField(schedule, "id", scheduleId)

        val scheduleSaveDto = ScheduleSaveDto(
            id = scheduleId,
            memberId = member.id!!,
            content = "schedule2",
            description = "description2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        whenever(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))
        whenever(scheduleRepository.save(any<Schedule>())).thenAnswer { it.getArgument<Schedule>(0) }

        // When
        val updatedSchedule = scheduleService.updateSchedule(loginMember, scheduleSaveDto)

        // Then
        assertThat(updatedSchedule).isNotNull
        assertThat(updatedSchedule.content).isEqualTo(scheduleSaveDto.content)
        assertThat(updatedSchedule.description).isEqualTo(scheduleSaveDto.description)
        assertThat(updatedSchedule.startDateTime).isEqualTo(scheduleSaveDto.startDateTime)
        assertThat(updatedSchedule.endDateTime).isEqualTo(scheduleSaveDto.endDateTime)
        assertThat(updatedSchedule.position).isEqualTo(0)

        verify(schedulePermissionService).checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)
        verify(scheduleRepository).save(schedule)
        verify(scheduleTimeParsingQueueManager).addTask(schedule)
    }

    @Test
    fun `can't update other member's schedule`() {
        // given
        val scheduleId = UUID.randomUUID()
        val schedule = Schedule(
            member = member2,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        ReflectionTestUtils.setField(schedule, "id", scheduleId)

        val scheduleSaveDto = ScheduleSaveDto(
            id = scheduleId,
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        whenever(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))
        whenever(schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember))
            .thenThrow(AuthException("login member doesn't have permission"))

        // When & Then
        assertThrows<AuthException> {
            scheduleService.updateSchedule(loginMember, scheduleSaveDto)
        }
    }

    @Test
    fun `delete schedule test`() {
        // given
        val scheduleId = UUID.randomUUID()
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        ReflectionTestUtils.setField(schedule, "id", scheduleId)

        whenever(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))
        whenever(attachmentRepository.findAllByContextTypeAndContextId(any(), any())).thenReturn(emptyList())
        whenever(pathResolver.resolveContextDirectory(any(), any())).thenReturn(java.nio.file.Paths.get("/tmp/test"))

        // When
        scheduleService.deleteSchedule(loginMember, scheduleId)

        // Then
        verify(schedulePermissionService).checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)
        verify(scheduleRepository).delete(schedule)
    }

    @Test
    fun `can't delete other member's schedule`() {
        // given
        val scheduleId = UUID.randomUUID()
        val schedule = Schedule(
            member = member2,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        ReflectionTestUtils.setField(schedule, "id", scheduleId)

        whenever(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))
        whenever(schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember))
            .thenThrow(AuthException("login member doesn't have permission"))

        // When & Then
        assertThrows<AuthException> {
            scheduleService.deleteSchedule(loginMember, scheduleId)
        }
    }

    @Test
    fun `create schedule with private visibility`() {
        // Given
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PRIVATE
        )

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(scheduleRepository.findMaxPosition(eq(member), any())).thenReturn(-1)
        whenever(scheduleRepository.save(any<Schedule>())).thenAnswer { invocation ->
            val schedule = invocation.getArgument<Schedule>(0)
            ReflectionTestUtils.setField(schedule, "id", UUID.randomUUID())
            schedule
        }

        // When
        val schedule = scheduleService.createSchedule(loginMember, scheduleSaveDto)

        // Then
        assertThat(schedule.visibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `create schedule with public visibility`() {
        // Given
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PUBLIC
        )

        whenever(memberRepository.findById(member.id!!)).thenReturn(Optional.of(member))
        whenever(scheduleRepository.findMaxPosition(eq(member), any())).thenReturn(-1)
        whenever(scheduleRepository.save(any<Schedule>())).thenAnswer { invocation ->
            val schedule = invocation.getArgument<Schedule>(0)
            ReflectionTestUtils.setField(schedule, "id", UUID.randomUUID())
            schedule
        }

        // When
        val schedule = scheduleService.createSchedule(loginMember, scheduleSaveDto)

        // Then
        assertThat(schedule.visibility).isEqualTo(Visibility.PUBLIC)
    }

    @Test
    fun `update schedule's visibility`() {
        // Given
        val scheduleId = UUID.randomUUID()
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0,
            visibility = Visibility.PRIVATE
        )
        ReflectionTestUtils.setField(schedule, "id", scheduleId)

        assertThat(schedule.visibility).isEqualTo(Visibility.PRIVATE)

        val scheduleSaveDto = ScheduleSaveDto(
            id = scheduleId,
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            visibility = Visibility.PUBLIC
        )

        whenever(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))
        whenever(scheduleRepository.save(any<Schedule>())).thenAnswer { it.getArgument<Schedule>(0) }

        // When
        val updatedSchedule = scheduleService.updateSchedule(loginMember, scheduleSaveDto)

        // Then
        assertThat(updatedSchedule.visibility).isEqualTo(Visibility.PUBLIC)
    }

}
