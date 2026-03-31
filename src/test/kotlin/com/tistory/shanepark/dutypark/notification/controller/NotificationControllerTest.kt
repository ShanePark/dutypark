package com.tistory.shanepark.dutypark.notification.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.service.NotificationPayloadCodec
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

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Autowired
    lateinit var notificationPayloadCodec: NotificationPayloadCodec

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
            .andExpect(jsonPath("$.content[0].payload.version").value(1))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-list",
                    queryParameters(
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size")
                    ),
                    responseFields(
                        fieldWithPath("content").description("List of notifications"),
                        fieldWithPath("content[].id").description("Notification ID (UUID)").optional(),
                        fieldWithPath("content[].type").description("Notification type (FRIEND_REQUEST_RECEIVED, FRIEND_REQUEST_ACCEPTED, FAMILY_REQUEST_RECEIVED, FAMILY_REQUEST_ACCEPTED, SCHEDULE_TAGGED, TODO_TAGGED, TODO_STATUS_TODO, TODO_STATUS_IN_PROGRESS, TODO_STATUS_DONE)").optional(),
                        fieldWithPath("content[].referenceType").description("Reference entity type (FRIEND_REQUEST, SCHEDULE, TODO, MEMBER) (nullable)").optional(),
                        fieldWithPath("content[].referenceId").description("Reference entity ID (nullable)").optional(),
                        fieldWithPath("content[].actorId").description("Actor member ID who triggered the notification (nullable)").optional(),
                        subsectionWithPath("content[].payload").description("Notification payload snapshot used for client-side rendering (missing or invalid payloads fall back to version 0 generic payload)").optional(),
                        fieldWithPath("content[].isRead").description("Whether notification has been read").optional(),
                        fieldWithPath("content[].createdAt").description("Notification created timestamp").optional(),
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
    fun `get notifications with pagination returns generic payload for invalid rows`() {
        createBrokenNotification(isRead = false)
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
            .andExpect(jsonPath("$.content[0].referenceId").value("broken"))
            .andExpect(jsonPath("$.content[0].payload.version").value(0))
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
            .andExpect(jsonPath("$[0].payload.version").value(1))
            .andExpect(jsonPath("$[0].payload.actor.name").value(TestData.member2.name))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-unread",
                    responseFields(
                        fieldWithPath("[].id").description("Notification ID (UUID)"),
                        fieldWithPath("[].type").description("Notification type (FRIEND_REQUEST_RECEIVED, FRIEND_REQUEST_ACCEPTED, FAMILY_REQUEST_RECEIVED, FAMILY_REQUEST_ACCEPTED, SCHEDULE_TAGGED, TODO_TAGGED, TODO_STATUS_TODO, TODO_STATUS_IN_PROGRESS, TODO_STATUS_DONE)"),
                        fieldWithPath("[].referenceType").description("Reference entity type (FRIEND_REQUEST, SCHEDULE, TODO, MEMBER) (nullable)"),
                        fieldWithPath("[].referenceId").description("Reference entity ID (nullable)"),
                        fieldWithPath("[].actorId").description("Actor member ID who triggered the notification (nullable)"),
                        subsectionWithPath("[].payload").description("Notification payload snapshot used for client-side rendering (missing or invalid payloads fall back to version 0 generic payload)"),
                        fieldWithPath("[].isRead").description("Whether notification has been read"),
                        fieldWithPath("[].createdAt").description("Notification created timestamp")
                    )
                )
            )
    }

    @Test
    fun `get unread notifications returns generic payload for invalid rows`() {
        createBrokenNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications/unread")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].referenceId").value("broken"))
            .andExpect(jsonPath("$[0].payload.version").value(0))
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
    fun `get notification count includes rows with fallback payload`() {
        createBrokenNotification(isRead = false)
        createTestNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications/count")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.unreadCount").value(2))
            .andExpect(jsonPath("$.totalCount").value(2))
    }

    @Test
    fun `get pending request count includes friend and family requests`() {
        friendRequestRepository.save(
            FriendRequest(
                fromMember = TestData.member2,
                toMember = TestData.member,
                status = FriendRequestStatus.PENDING,
                requestType = FriendRequestType.FRIEND_REQUEST,
            )
        )
        friendRequestRepository.save(
            FriendRequest(
                fromMember = TestData.admin,
                toMember = TestData.member,
                status = FriendRequestStatus.PENDING,
                requestType = FriendRequestType.FAMILY_REQUEST,
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/notifications/friend-request-count")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.count").value(2))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/get-friend-request-count",
                    responseFields(
                        fieldWithPath("count").description("Number of pending friend or family requests for the current member")
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
            .andExpect(jsonPath("$.payload.version").value(1))
            .andExpect(jsonPath("$.payload.actor.name").value(TestData.member2.name))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "notifications/mark-as-read",
                    pathParameters(
                        parameterWithName("id").description("Notification ID (UUID)")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Notification ID"),
                        fieldWithPath("type").description("Notification type (FRIEND_REQUEST_RECEIVED, FRIEND_REQUEST_ACCEPTED, FAMILY_REQUEST_RECEIVED, FAMILY_REQUEST_ACCEPTED, SCHEDULE_TAGGED, TODO_TAGGED, TODO_STATUS_TODO, TODO_STATUS_IN_PROGRESS, TODO_STATUS_DONE)"),
                        fieldWithPath("referenceType").description("Reference entity type (nullable)"),
                        fieldWithPath("referenceId").description("Reference entity ID (nullable)"),
                        fieldWithPath("actorId").description("Actor member ID (nullable)"),
                        subsectionWithPath("payload").description("Notification payload snapshot used for client-side rendering (missing or invalid payloads fall back to version 0 generic payload)"),
                        fieldWithPath("isRead").description("Whether notification has been read"),
                        fieldWithPath("createdAt").description("Notification created timestamp")
                    )
                )
            )
    }

    @Test
    fun `mark notification as read returns generic payload for invalid rows`() {
        val notification = createBrokenNotification(isRead = false)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/notifications/{id}/read", notification.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.isRead").value(true))
            .andExpect(jsonPath("$.payload.version").value(0))
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
        val payload = FriendRequestReceivedPayload(
            actor = NotificationActorSnapshot(
                name = TestData.member2.name,
                hasProfilePhoto = false,
                profilePhotoVersion = 0,
            )
        )
        val notification = Notification(
            member = TestData.member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = TestData.member2.id,
            payloadJson = notificationPayloadCodec.serialize(payload),
            payloadVersion = payload.version
        ).apply {
            this.isRead = isRead
        }
        return notificationRepository.save(notification)
    }

    private fun createBrokenNotification(isRead: Boolean = false): Notification {
        val notification = Notification(
            member = TestData.member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "broken",
            actorId = TestData.member2.id,
            payloadJson = null,
            payloadVersion = 1,
        ).apply {
            this.isRead = isRead
        }
        return notificationRepository.save(notification)
    }
}
