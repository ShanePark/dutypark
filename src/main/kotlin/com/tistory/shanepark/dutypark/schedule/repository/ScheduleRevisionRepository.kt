package com.tistory.shanepark.dutypark.schedule.repository

import com.tistory.shanepark.dutypark.schedule.domain.entity.ScheduleRevision
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.UUID

interface ScheduleRevisionRepository : JpaRepository<ScheduleRevision, UUID> {
    fun findAllByScheduleIdAndVersionIn(scheduleId: UUID, versions: Collection<Long>): List<ScheduleRevision>
    fun findByScheduleIdAndVersion(scheduleId: UUID, version: Long): ScheduleRevision?
    fun findAllByScheduleIdAndVersionLessThanEqualOrderByVersionAsc(scheduleId: UUID, version: Long): List<ScheduleRevision>
    fun findAllByScheduleIdOrderByVersionAsc(scheduleId: UUID): List<ScheduleRevision>
    @Query("SELECT DISTINCT r.schedule.id FROM ScheduleRevision r WHERE r.schedule.id IN :scheduleIds AND r.actorId <> r.schedule.member.id AND r.source = 'HUMAN'")
    fun findDelegatedScheduleIds(scheduleIds: Collection<UUID>): Set<UUID>

}
