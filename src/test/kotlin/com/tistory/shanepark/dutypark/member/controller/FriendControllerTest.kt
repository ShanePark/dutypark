package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
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

class FriendControllerTest : RestDocsTest() {

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Test
    fun `get friends list`() {
        makeThemFriend(TestData.member, TestData.member2)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/friends")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").isArray)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/get-list",
                    responseFields(
                        fieldWithPath("[].id").description("Friend member ID"),
                        fieldWithPath("[].name").description("Friend name"),
                        fieldWithPath("[].teamId").description("Friend team ID (nullable)"),
                        fieldWithPath("[].team").description("Friend team name (nullable)"),
                        fieldWithPath("[].hasProfilePhoto").description("Whether friend has profile photo"),
                        fieldWithPath("[].profilePhotoVersion").description("Profile photo version for cache busting")
                    )
                )
            )
    }

    @Test
    fun `search possible friends`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/friends/search")
                .param("keyword", "test")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/search",
                    queryParameters(
                        parameterWithName("keyword").description("Search keyword for member name"),
                        parameterWithName("page").description("Page number (0-based)"),
                        parameterWithName("size").description("Page size")
                    ),
                    responseFields(
                        fieldWithPath("content").description("List of possible friends"),
                        subsectionWithPath("content[]").description("Friend list items").optional(),
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
    fun `send friend request`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/friends/request/send/{toMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/send-request",
                    pathParameters(
                        parameterWithName("toMemberId").description("Target member ID to send friend request")
                    )
                )
            )
    }

    @Test
    fun `accept friend request`() {
        friendRequestRepository.save(
            FriendRequest(
                fromMember = TestData.member2,
                toMember = TestData.member,
                status = FriendRequestStatus.PENDING,
                requestType = FriendRequestType.FRIEND_REQUEST
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/friends/request/accept/{fromMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/accept-request",
                    pathParameters(
                        parameterWithName("fromMemberId").description("Member ID who sent the friend request")
                    )
                )
            )
    }

    @Test
    fun `reject friend request`() {
        friendRequestRepository.save(
            FriendRequest(
                fromMember = TestData.member2,
                toMember = TestData.member,
                status = FriendRequestStatus.PENDING,
                requestType = FriendRequestType.FRIEND_REQUEST
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/friends/request/reject/{fromMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/reject-request",
                    pathParameters(
                        parameterWithName("fromMemberId").description("Member ID who sent the friend request")
                    )
                )
            )
    }

    @Test
    fun `cancel friend request`() {
        friendRequestRepository.save(
            FriendRequest(
                fromMember = TestData.member,
                toMember = TestData.member2,
                status = FriendRequestStatus.PENDING,
                requestType = FriendRequestType.FRIEND_REQUEST
            )
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/friends/request/cancel/{toMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/cancel-request",
                    pathParameters(
                        parameterWithName("toMemberId").description("Member ID to cancel friend request")
                    )
                )
            )
    }

    @Test
    fun unfriend() {
        makeThemFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/friends/{deleteMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/unfriend",
                    pathParameters(
                        parameterWithName("deleteMemberId").description("Member ID to unfriend")
                    )
                )
            )
    }

    @Test
    fun `pin friend`() {
        makeThemFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/friends/pin/{friendId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/pin",
                    pathParameters(
                        parameterWithName("friendId").description("Friend ID to pin")
                    )
                )
            )
    }

    @Test
    fun `unpin friend`() {
        makeThemFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/friends/unpin/{friendId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/unpin",
                    pathParameters(
                        parameterWithName("friendId").description("Friend ID to unpin")
                    )
                )
            )
    }

    @Test
    fun `update friends pin order`() {
        makeThemFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        val json = "[${TestData.member2.id}]"

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/api/friends/pin/order")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/update-pin-order",
                    requestFields(
                        fieldWithPath("[]").description("Ordered list of friend IDs")
                    )
                )
            )
    }

    @Test
    fun `send family request`() {
        makeThemFriend(TestData.member, TestData.member2)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/friends/family/{toMemberId}", TestData.member2.id!!)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/send-family-request",
                    pathParameters(
                        parameterWithName("toMemberId").description("Friend ID to upgrade to family")
                    )
                )
            )
    }

}
