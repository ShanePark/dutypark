package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.common.config.DutyparkLocale
import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import jakarta.persistence.*

@Entity
class Member(
    @Column(nullable = false, length = 10)
    var name: String,

    @Column
    val email: String? = null,

    @Column
    var password: String? = null,

    ) : BaseTimeEntity() {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "team_id")
    var team: Team? = null

    @Column(nullable = false, name = "calendar_visibility")
    @Enumerated(EnumType.STRING)
    var calendarVisibility: Visibility = Visibility.FRIENDS

    @Column(name = "profile_photo_path")
    var profilePhotoPath: String? = null

    @Column(name = "profile_photo_version")
    var profilePhotoVersion: Long = 0

    @Column(name = "preferred_locale", nullable = false, length = 5)
    var preferredLocale: String = DutyparkLocale.DEFAULT

    fun hasProfilePhoto(): Boolean = profilePhotoPath != null

    fun incrementProfilePhotoVersion() {
        profilePhotoVersion++
    }

    override fun toString(): String {
        return "Member(name='$name', id=$id)"
    }

    fun isEquals(loginMember: LoginMember): Boolean {
        return this.id == loginMember.id
    }

}
