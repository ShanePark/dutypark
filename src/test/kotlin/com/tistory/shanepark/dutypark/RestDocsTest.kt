package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.security.filters.AdminAuthFilter
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.extension.ExtendWith
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.restdocs.AutoConfigureRestDocs
import org.springframework.restdocs.RestDocumentationContextProvider
import org.springframework.restdocs.RestDocumentationExtension
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.setup.DefaultMockMvcBuilder
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import org.springframework.web.context.WebApplicationContext

@ExtendWith(RestDocumentationExtension::class)
@AutoConfigureRestDocs(
    uriScheme = "https",
    uriHost = "dutypark.o-r.kr",
    uriPort = 443,
)
abstract class RestDocsTest : DutyparkIntegrationTest() {

    protected lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var jwtAuthFilter: JwtAuthFilter

    @BeforeEach
    fun setUp(webApplicationContext: WebApplicationContext, restDocumentation: RestDocumentationContextProvider) {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext)
            .apply<DefaultMockMvcBuilder>(MockMvcRestDocumentation.documentationConfiguration(restDocumentation))
            .addFilters<DefaultMockMvcBuilder>(jwtAuthFilter)
            .addFilters<DefaultMockMvcBuilder>(AdminAuthFilter(emptyList()))
            .build()
    }

}
