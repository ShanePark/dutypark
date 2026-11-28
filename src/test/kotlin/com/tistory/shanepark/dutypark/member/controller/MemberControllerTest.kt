package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.member.block.domain.entity.MemberBlock
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.content
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import java.nio.file.Files
import java.nio.file.Path
import javax.imageio.ImageIO
import java.awt.image.BufferedImage

class MemberControllerTest : RestDocsTest() {

    @Autowired
    lateinit var storagePathResolver: StoragePathResolver

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Autowired
    lateinit var memberBlockRepository: MemberBlockRepository

    private val createdDirectories = mutableListOf<Path>()

    @AfterEach
    fun cleanup() {
        createdDirectories.forEach { dir ->
            if (Files.exists(dir)) {
                Files.walk(dir)
                    .sorted(Comparator.reverseOrder())
                    .forEach { Files.deleteIfExists(it) }
            }
        }
        createdDirectories.clear()
    }

    @Test
    fun updateCalendarVisibility() {
        val member = TestData.member
        assertThat(member.calendarVisibility).isEqualTo(Visibility.FRIENDS)

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/${member.id}/visibility")
                .accept("application/json")
                .contentType("application/json")
                .content("{\"visibility\": \"PRIVATE\"}")
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "members/update-visibility",
                    requestFields(
                        fieldWithPath("visibility").description("Calendar visibility")
                    )
                )
            )

        val findMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(findMember.calendarVisibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `getProfilePhoto returns cache-control header for long-term caching`() {
        val member = TestData.member
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)
        Files.createDirectories(profileDir)

        val photoFilename = "test-photo.png"
        val photoPath = profileDir.resolve(photoFilename)
        createTestPngImage(photoPath)

        member.profilePhotoPath = "PROFILE/${member.id}/$photoFilename"
        memberRepository.save(member)
        em.flush()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/profile-photo")
        )
            .andExpect(status().isOk)
            .andExpect(header().exists(HttpHeaders.CACHE_CONTROL))
            .andExpect(header().string(HttpHeaders.CACHE_CONTROL, "max-age=31536000, public"))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `getProfilePhoto returns 404 when no photo exists`() {
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/profile-photo")
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `updateCalendarVisibility fails for other member`() {
        val member = TestData.member
        val other = TestData.member2

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/${other.id}/visibility")
                .accept("application/json")
                .contentType("application/json")
                .content("{\"visibility\": \"PRIVATE\"}")
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `createAuxiliaryAccount returns 400 when name missing`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/auxiliary")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                .accept("application/json")
                .contentType("application/json")
                .content("{}")
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("member.auxiliary.name.required"))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))
    }

    @Test
    fun `createAuxiliaryAccount rejects a name longer than the signup limit`() {
        val member = TestData.member
        val name = "x<img src=x onerror=alert(1)>"

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/auxiliary")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to name)))
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.length"))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))

        assertThat(memberRepository.findAll().none { it.name == name }).isTrue
    }

    @Test
    fun `createAuxiliaryAccount accepts a name at the signup limit`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/auxiliary")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "가나다라마바사아자차")))
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("가나다라마바사아자차"))
    }

    @Test
    fun `updateMyName trims and saves the name and returns the updated member`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "  새이름  ")))
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(member.id))
            .andExpect(jsonPath("$.name").value("새이름"))
            .andDo(
                document(
                    "members/update-name",
                    requestFields(
                        fieldWithPath("name").description("New display name (trimmed, 1-${Member.NAME_MAX_LENGTH} characters)")
                    )
                )
            )

        val findMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(findMember.name).isEqualTo("새이름")
    }

    @Test
    fun `updateMyName reissues the access token cookie with the new name on the same session`() {
        val member = TestData.member
        val session = sessionTokenService.createRefreshToken(member.id!!, "127.0.0.1", "integration-test")

        val response = mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "새이름")))
                .withAuth(member, session.id)
        )
            .andExpect(status().isOk)
            .andReturn().response

        val accessToken = response.getCookie("access_token")?.value
        assertThat(accessToken).isNotBlank
        val reissued = jwtProvider.parseToken(accessToken!!)
        assertThat(reissued.id).isEqualTo(member.id)
        assertThat(reissued.name).isEqualTo("새이름")
        assertThat(reissued.sessionId).isEqualTo(session.id)
        assertThat(reissued.isImpersonating).isFalse
        assertThat(response.getCookie("refresh_token")).isNull()
    }

    @Test
    fun `updateMyName returns 400 when name is blank`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "   ")))
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.required"))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))

        assertThat(memberRepository.findById(member.id!!).orElseThrow().name).isEqualTo(member.name)
    }

    @Test
    fun `updateMyName returns 400 when name is only ideographic space`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "　")))
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.required"))
            .andExpect(jsonPath("$.fieldErrors.length()").value(1))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))

        assertThat(memberRepository.findById(member.id!!).orElseThrow().name).isEqualTo(member.name)
    }

    @Test
    fun `updateMyName returns 400 when name is only no-break space`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to " ")))
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.required"))
            .andExpect(jsonPath("$.fieldErrors.length()").value(1))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))

        assertThat(memberRepository.findById(member.id!!).orElseThrow().name).isEqualTo(member.name)
    }

    @Test
    fun `updateMyName validates the length after trimming padding`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "  가나다라마바사아자차　")))
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("가나다라마바사아자차"))

        assertThat(memberRepository.findById(member.id!!).orElseThrow().name).isEqualTo("가나다라마바사아자차")
    }

    @Test
    fun `updateMyName returns 400 when name is missing`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content("{}")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.required"))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))
    }

    @Test
    fun `updateMyName rejects a name longer than the signup limit`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "가나다라마바사아자차카")))
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("sso.username.length"))
            .andExpect(jsonPath("$.fieldErrors[0].field").value("name"))

        assertThat(memberRepository.findById(member.id!!).orElseThrow().name).isEqualTo(member.name)
    }

    @Test
    fun `updateMyName accepts a name at the signup limit`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "가나다라마바사아자차")))
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("가나다라마바사아자차"))
    }

    @Test
    fun `updateMyName requires authentication`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "새이름")))
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `updateMyName while impersonating renames the impersonated member without reissuing a token`() {
        val target = TestData.member
        val impersonationToken = getImpersonationJwt(target, TestData.admin)

        val response = mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/name")
                .accept("application/json")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(mapOf("name" to "새이름")))
                .header(HttpHeaders.AUTHORIZATION, "Bearer $impersonationToken")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(target.id))
            .andExpect(jsonPath("$.name").value("새이름"))
            .andReturn().response

        assertThat(memberRepository.findById(target.id!!).orElseThrow().name).isEqualTo("새이름")
        assertThat(memberRepository.findById(TestData.admin.id!!).orElseThrow().name).isEqualTo(TestData.admin.name)
        assertThat(response.getCookie("access_token")).isNull()
    }

    @Test
    fun `amIManager returns false when not logged in`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/canManage")
        )
            .andExpect(status().isOk)
            .andExpect(content().string("false"))
    }

    @Test
    fun `admin can get private member details`() {
        val member = TestData.member
        member.calendarVisibility = Visibility.PRIVATE
        memberRepository.save(member)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}")
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(content().string(org.hamcrest.Matchers.containsString(member.name)))
    }

    @Test
    fun `public profile lookup does not expose sensitive account fields`() {
        val member = TestData.member
        member.calendarVisibility = Visibility.PUBLIC
        memberRepository.save(member)
        memberSocialAccountRepository.save(MemberSocialAccount(member, SsoType.KAKAO, "kakao-public"))
        memberSocialAccountRepository.save(MemberSocialAccount(member, SsoType.NAVER, "naver-public"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(member.id))
            .andExpect(jsonPath("$.name").value(member.name))
            .andExpect(jsonPath("$.email").doesNotExist())
            .andExpect(jsonPath("$.kakaoId").doesNotExist())
            .andExpect(jsonPath("$.naverId").doesNotExist())
            .andExpect(jsonPath("$.hasPassword").doesNotExist())
    }

    @Test
    fun `unlink social account deletes local mapping and returns 204`() {
        val member = TestData.member
        memberSocialAccountRepository.save(MemberSocialAccount(member, SsoType.KAKAO, "kakao-unlink"))
        memberSocialAccountRepository.save(MemberSocialAccount(member, SsoType.NAVER, "naver-retained"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/KAKAO")
                .withAuth(member)
        )
            .andExpect(status().isNoContent)

        assertThat(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).isNull()
        assertThat(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.NAVER)).isNotNull
    }

    @Test
    fun `unlink unlinked social account is idempotent`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/NAVER")
                .withAuth(TestData.member)
        )
            .andExpect(status().isNoContent)
    }

    @Test
    fun `unlink social account requires authentication`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/KAKAO")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `unlink social account rejects impersonation with machine readable code`() {
        val impersonationToken = getImpersonationJwt(TestData.member, TestData.admin)

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/KAKAO")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $impersonationToken")
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value("member.social.unlink.impersonationForbidden"))
    }

    @Test
    fun `unlink sole social account with password returns conflict and keeps mapping`() {
        val member = TestData.member
        assertThat(member.password).isNotBlank()
        val linked = memberSocialAccountRepository.save(
            MemberSocialAccount(member, SsoType.KAKAO, "kakao-last-authentication")
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/KAKAO")
                .withAuth(member)
        )
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.code").value("member.social.unlink.lastAuthenticationMethod"))

        assertThat(memberSocialAccountRepository.findById(linked.id!!)).isPresent
    }

    @Test
    fun `unlink unlinked Apple account is idempotent`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/members/me/social-accounts/APPLE")
                .withAuth(TestData.member)
        )
            .andExpect(status().isNoContent)
    }

    @Test
    fun `getProfilePhoto returns 404 when file is missing`() {
        val member = TestData.member
        val missingPath = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}/missing.png")
        member.profilePhotoPath = "PROFILE/${member.id}/missing.png"
        memberRepository.save(member)
        createdDirectories.add(missingPath.parent)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/profile-photo")
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `assignManager rejects a member who is not family`() {
        val managed = TestData.member
        val candidate = TestData.member2

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/manager/${candidate.id}")
                .withAuth(managed)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("friend.family.notFamily"))

        assertThat(memberManagerRepository.findAllByManagerAndManaged(candidate, managed)).isEmpty()
    }

    @Test
    fun `assignManager rejects a family member when either side has blocked the other`() {
        val managed = TestData.member
        val candidate = TestData.member2
        makeThemFamily(managed, candidate)
        memberBlockRepository.save(MemberBlock(blocker = candidate, blocked = managed))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/manager/${candidate.id}")
                .withAuth(managed)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("friend.request.blocked"))

        assertThat(memberManagerRepository.findAllByManagerAndManaged(candidate, managed)).isEmpty()
    }

    @Test
    fun `assignManager succeeds for a family member`() {
        val managed = TestData.member
        val candidate = TestData.member2
        makeThemFamily(managed, candidate)

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/manager/${candidate.id}")
                .withAuth(managed)
        )
            .andExpect(status().isOk)

        assertThat(memberManagerRepository.findAllByManagerAndManaged(candidate, managed)).hasSize(1)
    }

    @Test
    fun `managers response does not expose sensitive account fields`() {
        val managed = TestData.member
        val manager = TestData.member2
        makeThemFamily(managed, manager)
        makeManagerRelation(manager = manager, managed = managed)
        memberSocialAccountRepository.save(MemberSocialAccount(manager, SsoType.KAKAO, "kakao-manager"))
        memberSocialAccountRepository.save(MemberSocialAccount(manager, SsoType.NAVER, "naver-manager"))
        memberSocialAccountRepository.save(MemberSocialAccount(manager, SsoType.APPLE, "apple-manager"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/managers")
                .withAuth(managed)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$[0].id").value(manager.id))
            .andExpect(jsonPath("$[0].name").value(manager.name))
            .andExpect(jsonPath("$[0].email").doesNotExist())
            .andExpect(jsonPath("$[0].kakaoId").doesNotExist())
            .andExpect(jsonPath("$[0].naverId").doesNotExist())
            .andExpect(jsonPath("$[0].appleId").doesNotExist())
    }

    @Test
    fun `managed response does not expose sensitive account fields`() {
        val manager = TestData.member
        val managed = TestData.member2
        makeThemFamily(manager, managed)
        makeManagerRelation(manager = manager, managed = managed)
        memberSocialAccountRepository.save(MemberSocialAccount(managed, SsoType.KAKAO, "kakao-managed"))
        memberSocialAccountRepository.save(MemberSocialAccount(managed, SsoType.NAVER, "naver-managed"))
        memberSocialAccountRepository.save(MemberSocialAccount(managed, SsoType.APPLE, "apple-managed"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/managed")
                .withAuth(manager)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$[0].id").value(managed.id))
            .andExpect(jsonPath("$[0].name").value(managed.name))
            .andExpect(jsonPath("$[0].email").doesNotExist())
            .andExpect(jsonPath("$[0].kakaoId").doesNotExist())
            .andExpect(jsonPath("$[0].naverId").doesNotExist())
            .andExpect(jsonPath("$[0].appleId").doesNotExist())
    }

    private fun makeThemFamily(member1: Member, member2: Member) {
        friendRelationRepository.save(FriendRelation(member1, member2).apply { isFamily = true })
        friendRelationRepository.save(FriendRelation(member2, member1).apply { isFamily = true })
    }

    private fun createTestPngImage(path: Path) {
        val image = BufferedImage(100, 100, BufferedImage.TYPE_INT_ARGB)
        val graphics = image.createGraphics()
        graphics.fillRect(0, 0, 100, 100)
        graphics.dispose()
        ImageIO.write(image, "png", path.toFile())
    }

}
