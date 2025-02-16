package com.tistory.shanepark.dutypark.duty.batch.exceptions

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType

class DutyTypeNotSingleException(dutyTypes: List<DutyType>) :
    DutyBatchException("파일 업로드로 시간표를 등록하기 위해서는 사용자가 속한 부서의 근무 유형이 1개여야 합니다. \n근무유형이 ${dutyTypes.size}개 등록되어 있습니다: ${dutyTypes.map { it.name }}")
