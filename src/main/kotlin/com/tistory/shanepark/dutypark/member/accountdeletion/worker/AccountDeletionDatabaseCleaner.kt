package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class AccountDeletionDatabaseCleaner(
    private val jdbc: NamedParameterJdbcTemplate,
) {
    @Transactional
    fun clean(memberIds: List<Long>, teamIds: List<Long>) {
        val memberParams = MapSqlParameterSource("memberIds", memberIds)
        val teamParams = MapSqlParameterSource("teamIds", teamIds.ifEmpty { listOf(-1L) })

        reassignRetainedTeamContent(memberIds, teamIds)

        update("delete from schedule_tags where member_id in (:memberIds)", memberParams)
        update("delete from todo_tags where member_id in (:memberIds)", memberParams)
        update("delete from notifications where member_id in (:memberIds) or actor_id in (:memberIds)", memberParams)
        update("delete from friends where member_id in (:memberIds) or friend_id in (:memberIds)", memberParams)
        update("delete from friend_requests where from_member_id in (:memberIds) or to_member_id in (:memberIds)", memberParams)
        update("delete from member_manager where manager_id in (:memberIds) or managed_id in (:memberIds)", memberParams)
        update("delete from team_managers where member_id in (:memberIds)", memberParams)

        val scheduleIds = ids("select id from schedule where member_id in (:memberIds)", memberParams)
        deleteAttachmentsForContexts("SCHEDULE", scheduleIds)
        if (scheduleIds.isNotEmpty()) {
            update("delete from schedule_tags where schedule_id in (:ids)", MapSqlParameterSource("ids", scheduleIds))
        }
        update("delete from schedule where member_id in (:memberIds)", memberParams)

        val todoIds = ids("select id from todo where member_id in (:memberIds)", memberParams)
        deleteAttachmentsForContexts("TODO", todoIds)
        if (todoIds.isNotEmpty()) {
            update("delete from todo_tags where todo_id in (:ids)", MapSqlParameterSource("ids", todoIds))
        }
        update("delete from todo where member_id in (:memberIds)", memberParams)

        deleteAttachmentsForContexts("PROFILE", memberIds.map(Long::toString))
        update("delete from attachment where created_by in (:memberIds) and context_type <> 'TEAM'", memberParams)
        val sessionIds = ids("select id from attachment_upload_session where owner_id in (:memberIds)", memberParams)
        if (sessionIds.isNotEmpty()) {
            update("delete from attachment where upload_session_id in (:ids)", MapSqlParameterSource("ids", sessionIds))
        }
        update("delete from attachment_upload_session where owner_id in (:memberIds)", memberParams)

        update(
            "delete from member_duty_pattern_weekday where pattern_id in " +
                "(select id from member_duty_pattern where member_id in (:memberIds))",
            memberParams,
        )
        update("delete from member_duty_pattern where member_id in (:memberIds)", memberParams)
        update("delete from duty where member_id in (:memberIds)", memberParams)
        update("delete from d_day_event where member_id in (:memberIds)", memberParams)

        deleteRefreshTokens(memberIds)
        update("delete from mobile_oauth_transaction where link_member_id in (:memberIds) or member_id in (:memberIds)", memberParams)
        update("delete from account_reauth_proof where member_id in (:memberIds)", memberParams)
        update("delete from member_consent where member_id in (:memberIds)", memberParams)
        update("delete from member_social_account where member_id in (:memberIds)", memberParams)

        deleteTeams(teamIds, teamParams)

        update("update team set admin_id = null where admin_id in (:memberIds)", memberParams)
        update("update member set team_id = null where id in (:memberIds)", memberParams)
        update("delete from member where id in (:memberIds)", memberParams)
    }

    private fun reassignRetainedTeamContent(memberIds: List<Long>, deletedTeamIds: List<Long>) {
        val params = MapSqlParameterSource()
            .addValue("memberIds", memberIds)
            .addValue("deletedTeamIds", deletedTeamIds.ifEmpty { listOf(-1L) })
        val retainedTeams = jdbc.query(
            """
            select distinct ts.team_id, t.admin_id
            from team_schedule ts join team t on t.id = ts.team_id
            where (ts.create_member_id in (:memberIds) or ts.update_member_id in (:memberIds))
              and ts.team_id not in (:deletedTeamIds)
            """.trimIndent(),
            params,
        ) { rs, _ -> rs.getLong("team_id") to rs.getObject("admin_id", java.lang.Long::class.java)?.toLong() }
        retainedTeams.forEach { (teamId, adminId) ->
            if (adminId == null || adminId in memberIds) {
                throw IllegalStateException("accountDeletion.missingRetainedTeamAdmin")
            }
            update(
                "update team_schedule set create_member_id = :adminId where team_id = :teamId and create_member_id in (:memberIds)",
                MapSqlParameterSource().addValue("adminId", adminId).addValue("teamId", teamId).addValue("memberIds", memberIds),
            )
            update(
                "update team_schedule set update_member_id = :adminId where team_id = :teamId and update_member_id in (:memberIds)",
                MapSqlParameterSource().addValue("adminId", adminId).addValue("teamId", teamId).addValue("memberIds", memberIds),
            )
            update(
                "update attachment set created_by = :adminId where context_type = 'TEAM' and context_id = :teamId and created_by in (:memberIds)",
                MapSqlParameterSource().addValue("adminId", adminId).addValue("teamId", teamId.toString()).addValue("memberIds", memberIds),
            )
        }

        val retainedAttachmentTeamIds = jdbc.queryForList(
            """
            select distinct context_id
            from attachment
            where context_type = 'TEAM' and created_by in (:memberIds) and context_id not in (:deletedTeamIds)
            """.trimIndent(),
            params,
            String::class.java,
        ).filterNotNull().mapNotNull(String::toLongOrNull).filterNot { id -> retainedTeams.any { it.first == id } }
        retainedAttachmentTeamIds.forEach { teamId ->
            val adminId = jdbc.queryForObject(
                "select admin_id from team where id = :teamId",
                mapOf("teamId" to teamId),
                java.lang.Long::class.java,
            )?.toLong() ?: throw IllegalStateException("accountDeletion.missingRetainedTeamAdmin")
            if (adminId in memberIds) throw IllegalStateException("accountDeletion.missingRetainedTeamAdmin")
            update(
                "update attachment set created_by = :adminId where context_type = 'TEAM' and context_id = :teamId and created_by in (:memberIds)",
                MapSqlParameterSource().addValue("adminId", adminId).addValue("teamId", teamId.toString()).addValue("memberIds", memberIds),
            )
        }
    }

    private fun deleteTeams(teamIds: List<Long>, params: MapSqlParameterSource) {
        if (teamIds.isEmpty()) return
        val teamIdStrings = teamIds.map(Long::toString)
        deleteAttachmentsForContexts("TEAM", teamIdStrings)
        update("delete from team_schedule where team_id in (:teamIds)", params)
        update(
            "delete from member_duty_pattern_weekday where pattern_id in " +
                "(select id from member_duty_pattern where team_id in (:teamIds))",
            params,
        )
        update("delete from member_duty_pattern where team_id in (:teamIds)", params)
        update("delete from duty where team_id in (:teamIds)", params)
        update(
            "delete from duty where duty_type_id in (select id from duty_type where team_id in (:teamIds))",
            params,
        )
        update("delete from team_managers where team_id in (:teamIds)", params)
        update("update member set team_id = null where team_id in (:teamIds)", params)
        update("update team set admin_id = null where id in (:teamIds)", params)
        update("delete from duty_type where team_id in (:teamIds)", params)
        update("delete from team where id in (:teamIds)", params)
    }

    private fun deleteRefreshTokens(memberIds: List<Long>) {
        val params = MapSqlParameterSource("memberIds", memberIds)
        val refreshIds = jdbc.queryForList(
            "select id from refresh_token where member_id in (:memberIds)",
            params,
            java.lang.Long::class.java,
        ).mapNotNull { it?.toLong() }
        if (refreshIds.isNotEmpty()) {
            update("delete from apns_installation where refresh_token_id in (:ids)", MapSqlParameterSource("ids", refreshIds))
        }
        update("delete from refresh_token where member_id in (:memberIds)", params)
    }

    private fun deleteAttachmentsForContexts(type: String, contextIds: List<String>) {
        if (contextIds.isEmpty()) return
        update(
            "delete from attachment where context_type = :type and context_id in (:ids)",
            MapSqlParameterSource().addValue("type", type).addValue("ids", contextIds),
        )
    }

    private fun ids(sql: String, params: MapSqlParameterSource): List<String> =
        jdbc.queryForList(sql, params, String::class.java).filterNotNull()

    private fun update(sql: String, params: MapSqlParameterSource) {
        jdbc.update(sql, params)
    }
}
