package com.tistory.shanepark.dutypark.common.config

import com.tistory.shanepark.dutypark.security.config.LoginMemberArgumentResolver
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean

@Configuration
class WebMvcSupportConfig {

    @Bean
    fun loginMemberArgumentResolver(): LoginMemberArgumentResolver {
        return LoginMemberArgumentResolver()
    }

    @Bean("validator")
    fun validator(): LocalValidatorFactoryBean {
        return LocalValidatorFactoryBean()
    }
}
