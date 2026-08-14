package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.FileSystemService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.stereotype.Component
import java.util.UUID

@Component
class AccountDeletionFileCleaner(
    private val jdbc: NamedParameterJdbcTemplate,
    private val pathResolver: StoragePathResolver,
    private val fileSystemService: FileSystemService,
) {
    fun deleteFiles(memberIds: List<Long>, teamIds: List<Long>) {
        val memberParams = MapSqlParameterSource("memberIds", memberIds)
        contextIds("select id from schedule where member_id in (:memberIds)", memberParams)
            .forEach { deleteContext(AttachmentContextType.SCHEDULE, it) }
        contextIds("select id from todo where member_id in (:memberIds)", memberParams)
            .forEach { deleteContext(AttachmentContextType.TODO, it) }
        memberIds.forEach { deleteContext(AttachmentContextType.PROFILE, it.toString()) }
        teamIds.forEach { deleteContext(AttachmentContextType.TEAM, it.toString()) }

        jdbc.queryForList(
            "select id from attachment_upload_session where owner_id in (:memberIds)",
            memberParams,
            String::class.java,
        ).map(UUID::fromString).forEach { sessionId ->
            fileSystemService.deleteDirectory(pathResolver.resolveTemporaryDirectory(sessionId))
        }

        val teamIdStrings = teamIds.map(Long::toString)
        val params = MapSqlParameterSource()
            .addValue("memberIds", memberIds)
            .addValue("teamIds", teamIdStrings.ifEmpty { listOf("__none__") })
        jdbc.query(
            """
            select context_type, context_id, upload_session_id, stored_filename, thumbnail_filename
            from attachment
            where created_by in (:memberIds)
              and not (context_type = 'TEAM' and context_id not in (:teamIds))
            """.trimIndent(),
            params,
        ) { rs ->
            val type = AttachmentContextType.valueOf(rs.getString("context_type"))
            val contextId = rs.getString("context_id")
            val sessionId = rs.getString("upload_session_id")?.let(UUID::fromString)
            val file = pathResolver.resolveFilePath(type, contextId, sessionId, rs.getString("stored_filename"))
            fileSystemService.deleteFile(file)
            rs.getString("thumbnail_filename")?.let { thumbnail ->
                fileSystemService.deleteFile(pathResolver.resolveThumbnailPath(type, contextId, sessionId, thumbnail))
            }
        }
    }

    private fun contextIds(sql: String, params: MapSqlParameterSource): List<String> =
        jdbc.queryForList(sql, params, String::class.java).filterNotNull()

    private fun deleteContext(type: AttachmentContextType, contextId: String) {
        fileSystemService.deleteDirectory(pathResolver.resolveContextDirectory(type, contextId))
    }
}
