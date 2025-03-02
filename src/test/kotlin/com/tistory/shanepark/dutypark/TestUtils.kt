package com.tistory.shanepark.dutypark

import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule

class TestUtils {

    companion object {
        fun jsr310ObjectMapper(): ObjectMapper {
            return ObjectMapper()
                .setSerializationInclusion(JsonInclude.Include.NON_NULL)
                .registerModule(JavaTimeModule())
        }
    }

}
