package com.tistory.shanepark.dutypark.common.idempotency

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import java.util.UUID

@DataJpaTest
class CreateIdempotencyKeyRepositoryTest {

    @Autowired
    private lateinit var repository: CreateIdempotencyKeyRepository

    @Autowired
    private lateinit var memberRepository: MemberRepository

    @Test
    fun `finds a key by authenticated account operation and resource kind`() {
        val member = memberRepository.save(Member(name = "offline"))
        val operationId = UUID.randomUUID().toString()
        val resourceId = UUID.randomUUID().toString()
        val key = repository.save(
            CreateIdempotencyKey(
                member = member,
                operationId = operationId,
                resourceKind = CreateIdempotencyResource.TODO,
            )
        )
        key.resourceId = resourceId
        repository.flush()

        val result = repository.findByMemberIdAndOperationIdAndResourceKind(
            memberId = member.id!!,
            operationId = operationId,
            resourceKind = CreateIdempotencyResource.TODO,
        )

        assertThat(result).isPresent
        assertThat(result.get().member.id).isEqualTo(member.id)
        assertThat(result.get().resourceKind).isEqualTo(CreateIdempotencyResource.TODO)
        assertThat(result.get().resourceId).isEqualTo(resourceId)
    }
}
