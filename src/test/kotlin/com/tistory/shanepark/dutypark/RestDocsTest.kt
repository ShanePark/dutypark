package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.extension.ExtendWith
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.restdocs.AutoConfigureRestDocs
import org.springframework.http.HttpHeaders
import org.springframework.restdocs.RestDocumentationContextProvider
import org.springframework.restdocs.RestDocumentationExtension
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder
import org.springframework.test.web.servlet.setup.DefaultMockMvcBuilder
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import org.springframework.web.context.WebApplicationContext

@ExtendWith(RestDocumentationExtension::class)
@AutoConfigureRestDocs(
    uriScheme = "https",
    uriHost = "dutypark.kr",
    uriPort = 443,
)
abstract class RestDocsTest : DutyparkIntegrationTest() {

    protected lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var authService: AuthService

    @Autowired
    lateinit var cookieService: CookieService

    @BeforeEach
    fun setUp(webApplicationContext: WebApplicationContext, restDocumentation: RestDocumentationContextProvider) {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext)
            .apply<DefaultMockMvcBuilder>(MockMvcRestDocumentation.documentationConfiguration(restDocumentation))
            .addFilters<DefaultMockMvcBuilder>(JwtAuthFilter(authService, cookieService))
            .build()
    }

    protected fun MockHttpServletRequestBuilder.withAuth(member: Member): MockHttpServletRequestBuilder {
        return this.header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
    }

}
