package com.tistory.shanepark.dutypark.duty.batch.exceptions

class MultipleNameFoundException(val names: List<String>) :
    DutyBatchException("사용자의 이름이 여러개 존재합니다: ${names.joinToString()}")
