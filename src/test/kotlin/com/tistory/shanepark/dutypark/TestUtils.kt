package com.tistory.shanepark.dutypark

import com.fasterxml.jackson.annotation.JsonInclude
import tools.jackson.databind.json.JsonMapper

class TestUtils {

    companion object {
        fun jsr310JsonMapper(): JsonMapper {
            return JsonMapper.builder()
                .changeDefaultPropertyInclusion { it
                    .withValueInclusion(JsonInclude.Include.NON_NULL)
                    .withContentInclusion(JsonInclude.Include.NON_NULL)
                }
                .build()
        }
    }

}
