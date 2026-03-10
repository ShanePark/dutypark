package com.tistory.shanepark.dutypark.security.oauth

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType

class SocialAccountAlreadyLinkedException(
    val provider: SsoType
) : IllegalArgumentException("${provider.name} account is already linked to another member")
