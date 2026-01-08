package com.tistory.shanepark.dutypark.notification.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class NotificationControllerTest : RestDocsTest() {

    @Autowired
    lateinit var notificationRepository: NotificationRepository

    @Test
    fun `get notifications with pagination`() {
        createTestNotification()
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications")
                .param("page", "0")
                .param("size", "20")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-list",
                    queryParameters(
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size (max 50)")
                    ),
                    responseFields(
                        fieldWithPath("content").description("List of notifications"),
                        subsectionWithPath("content[]").description("Notification items").optional(),
                        fieldWithPath("totalPages").description("Total pages"),
                        fieldWithPath("totalElements").description("Total elements"),
                        fieldWithPath("first").description("Is first page"),
                        fieldWithPath("last").description("Is last page"),
                        fieldWithPath("size").description("Page size"),
                        fieldWithPath("number").description("Current page number"),
                        fieldWithPath("numberOfElements").description("Number of elements in current page"),
                        fieldWithPath("empty").description("Is empty"),
                        fieldWithPath("pageable").description("Pageable info"),
                        fieldWithPath("pageable.pageNumber").description("Page number"),
                        fieldWithPath("pageable.pageSize").description("Page size"),
                        fieldWithPath("pageable.sort").description("Sort info"),
                        fieldWithPath("pageable.sort.empty").description("Is sort empty"),
                        fieldWithPath("pageable.sort.sorted").description("Is sorted"),
                        fieldWithPath("pageable.sort.unsorted").description("Is unsorted"),
                        fieldWithPath("pageable.offset").description("Offset"),
                        fieldWithPath("pageable.paged").description("Is paged"),
                        fieldWithPath("pageable.unpaged").description("Is unpaged")
                    )
                )
            )
    }

    @Test
    fun `get unread notifications`() {
        createTestNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications/unread")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-unread",
                    responseFields(
                        fieldWithPath("[].id").description("Notification ID (UUID)"),
                        fieldWithPath("[].type").description("Notification type (FRIEND_REQUEST_RECEIVED, FRIEND_REQUEST_ACCEPTED, FAMILY_REQUEST_RECEIVED, FAMILY_REQUEST_ACCEPTED, SCHEDULE_TAGGED)"),
                        fieldWithPath("[].title").description("Notification title"),
                        fieldWithPath("[].content").description("Notification content (nullable)"),
                        fieldWithPath("[].referenceType").description("Reference entity type (FRIEND_REQUEST, SCHEDULE, MEMBER) (nullable)"),
                        fieldWithPath("[].referenceId").description("Reference entity ID (nullable)"),
                        fieldWithPath("[].actorId").description("Actor member ID who triggered the notification (nullable)"),
                        fieldWithPath("[].actorName").description("Actor member name (nullable)"),
                        fieldWithPath("[].actorHasProfilePhoto").description("Whether actor has profile photo"),
                        fieldWithPath("[].actorProfilePhotoVersion").description("Actor profile photo version"),
                        fieldWithPath("[].isRead").description("Whether notification has been read"),
                        fieldWithPath("[].createdAt").description("Notification created timestamp")
                    )
                )
            )
    }

    @Test
    fun `get notification count`() {
        createTestNotification(isRead = false)
        createTestNotification(isRead = true)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications/count")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.unreadCount").value(1))
            .andExpect(jsonPath("$.totalCount").value(2))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-count",
                    responseFields(
                        fieldWithPath("unreadCount").description("Number of unread notifications"),
                        fieldWithPath("totalCount").description("Total number of notifications")
                    )
                )
            )
    }

    @Test
    fun `mark notification as read`() {
        val notification = createTestNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/notifications/{id}/read", notification.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.isRead").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/mark-as-read",
                    pathParameters(
                        parameterWithName("id").description("Notification ID (UUID)")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Notification ID"),
                        fieldWithPath("type").description("Notification type"),
                        fieldWithPath("title").description("Notification title"),
                        fieldWithPath("content").description("Notification content (nullable)"),
                        fieldWithPath("referenceType").description("Reference entity type (nullable)"),
                        fieldWithPath("referenceId").description("Reference entity ID (nullable)"),
                        fieldWithPath("actorId").description("Actor member ID (nullable)"),
                        fieldWithPath("actorName").description("Actor member name (nullable)"),
                        fieldWithPath("actorHasProfilePhoto").description("Whether actor has profile photo"),
                        fieldWithPath("actorProfilePhotoVersion").description("Actor profile photo version"),
                        fieldWithPath("isRead").description("Whether notification has been read"),
                        fieldWithPath("createdAt").description("Notification created timestamp")
                    )
                )
            )
    }

    @Test
    fun `mark all notifications as read`() {
        createTestNotification(isRead = false)
        createTestNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/notifications/read-all")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.count").value(2))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/mark-all-as-read",
                    responseFields(
                        fieldWithPath("count").description("Number of notifications marked as read")
                    )
                )
            )
    }

    @Test
    fun `delete notification`() {
        val notification = createTestNotification()
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/notifications/{id}", notification.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/delete",
                    pathParameters(
                        parameterWithName("id").description("Notification ID (UUID) to delete")
                    )
                )
            )
    }

    @Test
    fun `delete all read notifications`() {
        createTestNotification(isRead = true)
        createTestNotification(isRead = true)
        createTestNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/notifications/read")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.count").value(2))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/delete-all-read",
                    responseFields(
                        fieldWithPath("count").description("Number of read notifications deleted")
                    )
                )
            )
    }

    private fun createTestNotification(isRead: Boolean = false): Notification {
        val notification = Notification(
            member = TestData.member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            title = "${TestData.member2.name}님이 친구 요청을 보냈습니다",
            content = null,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = TestData.member2.id
        ).apply {
            this.isRead = isRead
        }
        return notificationRepository.save(notification)
    }
}
