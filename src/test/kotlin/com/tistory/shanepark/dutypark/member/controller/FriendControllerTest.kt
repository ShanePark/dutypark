package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import jakarta.servlet.http.Cookie
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers

class FriendControllerTest : RestDocsTest() {

    @Autowired
    lateinit var friendRepository: FriendRelationRepository

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository

    @Test
    fun friendInfo() {
        // Given
        val member = TestData.member

        val randomUsers = makeRandomUser(10);
        // foreach until 5th element of
        randomUsers.subList(1, 5).forEach {
            friendRepository.save(FriendRelation(member, it))
            friendRepository.save(FriendRelation(it, member))
        }

        randomUsers.subList(5, 7).forEach {
            friendRequestRepository.save(FriendRequest(member, it))
        }

        randomUsers.subList(7, 10).forEach {
            friendRequestRepository.save(FriendRequest(it, member))
        }

        // Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/friends")
                .accept("application/json")
                .cookie(Cookie(jwtConfig.cookieName, getJwt(member)))
        ).andExpect(MockMvcResultMatchers.status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "friends/friend-info",
                    responseFields(
                        fieldWithPath("friends[].id").description("The friend's ID"),
                        fieldWithPath("friends[].name").description("The friend's name"),
                        fieldWithPath("friends[].email").description("The friend's email address"),
                        fieldWithPath("friends[].departmentId").description("The friend's department ID"),
                        fieldWithPath("friends[].department").description("The friend's department name"),
                        fieldWithPath("friends[].managerId").optional().description("The friend's manager ID (if any)"),
                        fieldWithPath("pendingRequestsTo[].id").description("The request ID"),
                        fieldWithPath("pendingRequestsTo[].status").description("The status of the request"),
                        fieldWithPath("pendingRequestsTo[].createdAt").description("The date and time the request was created"),
                        fieldWithPath("pendingRequestsTo[].fromMember.id").description("The ID of the member who sent the request"),
                        fieldWithPath("pendingRequestsTo[].fromMember.name").description("The name of the member who sent the request"),
                        fieldWithPath("pendingRequestsTo[].fromMember.email").description("The email address of the member who sent the request"),
                        fieldWithPath("pendingRequestsTo[].fromMember.departmentId").description("The department ID of the member who sent the request"),
                        fieldWithPath("pendingRequestsTo[].fromMember.department").description("The department name of the member who sent the request"),
                        fieldWithPath("pendingRequestsTo[].fromMember.managerId").optional()
                            .description("The manager ID of the member who sent the request (if any)"),
                        fieldWithPath("pendingRequestsTo[].toMember.id").description("The ID of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsTo[].toMember.name").description("The name of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsTo[].toMember.email").description("The email address of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsTo[].toMember.departmentId").description("The department ID of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsTo[].toMember.department").description("The department name of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsTo[].toMember.managerId").optional()
                            .description("The manager ID of the member to whom the request was sent (if any)"),
                        fieldWithPath("pendingRequestsFrom[].id").description("The request ID"),
                        fieldWithPath("pendingRequestsFrom[].status").description("The status of the request"),
                        fieldWithPath("pendingRequestsFrom[].createdAt").description("The date and time the request was created"),
                        fieldWithPath("pendingRequestsFrom[].toMember.id").description("The ID of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsFrom[].toMember.name").description("The name of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsFrom[].toMember.email").description("The email address of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsFrom[].toMember.departmentId").description("The department ID of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsFrom[].toMember.department").description("The department name of the member to whom the request was sent"),
                        fieldWithPath("pendingRequestsFrom[].toMember.managerId").optional()
                            .description("The manager ID of the member to whom the request was sent (if any)"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.id").description("The ID of the member who sent the request"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.name").description("The name of the member who sent the request"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.email").description("The email address of the member who sent the request"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.departmentId").description("The department ID of the member who sent the request"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.department").description("The department name of the member who sent the request"),
                        fieldWithPath("pendingRequestsFrom[].fromMember.managerId").optional()
                            .description("The manager ID of the member who sent the request (if any)")
                    )
                )

            )
    }

    private fun makeRandomUser(cnt: Int): List<Member> {
        val members = mutableListOf<Member>()
        for (i in 1..cnt) {
            val member: Member = Member("name$i", "email$i", "password")
            memberRepository.save(member)
            members.add(member)
        }
        return members
    }
}
