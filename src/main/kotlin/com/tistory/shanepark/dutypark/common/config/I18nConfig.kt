package com.tistory.shanepark.dutypark.common.config

import com.tistory.shanepark.dutypark.security.config.LoginMemberArgumentResolver
import org.springframework.context.MessageSource
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.support.ReloadableResourceBundleMessageSource
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean
import org.springframework.web.servlet.LocaleResolver
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver
import java.nio.charset.StandardCharsets
import java.util.Locale

@Configuration
class I18nConfig {

    @Bean
    fun loginMemberArgumentResolver(): LoginMemberArgumentResolver {
        return LoginMemberArgumentResolver()
    }

    @Bean
    fun messageSource(): MessageSource {
        return ReloadableResourceBundleMessageSource().apply {
            setBasenames("classpath:messages")
            setDefaultEncoding(StandardCharsets.UTF_8.name())
            setFallbackToSystemLocale(false)
            setUseCodeAsDefaultMessage(true)
        }
    }

    @Bean
    fun localeResolver(): LocaleResolver {
        return AcceptHeaderLocaleResolver().apply {
            setDefaultLocale(Locale.KOREAN)
            setSupportedLocales(DutyparkLocale.SUPPORTED_LOCALES)
        }
    }

    @Bean(name = ["validator"])
    fun validator(messageSource: MessageSource): LocalValidatorFactoryBean {
        return LocalValidatorFactoryBean().apply {
            setValidationMessageSource(messageSource)
        }
    }
}
