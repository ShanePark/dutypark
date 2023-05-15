package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.actuate.autoconfigure.endpoint.web.CorsEndpointProperties
import org.springframework.boot.actuate.autoconfigure.endpoint.web.WebEndpointProperties
import org.springframework.boot.actuate.autoconfigure.endpoint.web.servlet.WebMvcEndpointManagementContextConfiguration
import org.springframework.boot.actuate.endpoint.web.EndpointMediaTypes
import org.springframework.boot.actuate.endpoint.web.WebEndpointsSupplier
import org.springframework.boot.actuate.endpoint.web.annotation.ControllerEndpointsSupplier
import org.springframework.boot.actuate.endpoint.web.annotation.ServletEndpointsSupplier
import org.springframework.boot.actuate.endpoint.web.servlet.WebMvcEndpointHandlerMapping
import org.springframework.context.annotation.Configuration
import org.springframework.core.env.Environment

@Configuration
class ActuatorConfig(
    private val jwtAuthInterceptor: JwtAuthInterceptor,
    private val adminAuthInterceptor: AdminAuthInterceptor,
) : WebMvcEndpointManagementContextConfiguration() {

    override fun webEndpointServletHandlerMapping(
        webEndpointsSupplier: WebEndpointsSupplier?,
        servletEndpointsSupplier: ServletEndpointsSupplier?,
        controllerEndpointsSupplier: ControllerEndpointsSupplier?,
        endpointMediaTypes: EndpointMediaTypes?,
        corsProperties: CorsEndpointProperties?,
        webEndpointProperties: WebEndpointProperties?,
        environment: Environment?
    ): WebMvcEndpointHandlerMapping {

        val webEndpointServletHandlerMapping = super.webEndpointServletHandlerMapping(
            webEndpointsSupplier,
            servletEndpointsSupplier,
            controllerEndpointsSupplier,
            endpointMediaTypes,
            corsProperties,
            webEndpointProperties,
            environment
        )

        webEndpointServletHandlerMapping.setInterceptors(jwtAuthInterceptor)
        webEndpointServletHandlerMapping.setInterceptors(adminAuthInterceptor)

        return webEndpointServletHandlerMapping
    }
}
