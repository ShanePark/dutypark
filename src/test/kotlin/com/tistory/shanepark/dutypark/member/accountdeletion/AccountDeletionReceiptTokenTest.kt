package com.tistory.shanepark.dutypark.member.accountdeletion

import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionReceiptToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class AccountDeletionReceiptTokenTest {
    @Test
    fun `generated receipts are 256 bit base64url values and hash to 256 bits`() {
        val first = AccountDeletionReceiptToken.generate()
        val second = AccountDeletionReceiptToken.generate()

        assertThat(first).hasSize(43).matches("[A-Za-z0-9_-]+")
        assertThat(second).hasSize(43).matches("[A-Za-z0-9_-]+")
        assertThat(first).isNotEqualTo(second)
        assertThat(AccountDeletionReceiptToken.hash(first)).hasSize(64).matches("[0-9a-f]{64}")
    }

    @Test
    fun `only the exact generated token shape is accepted`() {
        val generated = AccountDeletionReceiptToken.generate()

        assertThat(AccountDeletionReceiptToken.isValid(generated)).isTrue()
        assertThat(AccountDeletionReceiptToken.isValid(generated.dropLast(1))).isFalse()
        assertThat(AccountDeletionReceiptToken.isValid(generated.replaceRange(0, 1, "+"))).isFalse()
    }
}
