package com.tistory.shanepark.dutypark.team.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import jakarta.persistence.*

@Entity
@Table(name = "team")
class Team(
    @Column(unique = true)
    var name: String,
) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    var description: String = ""

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id")
    var admin: Member? = null

    @OneToMany(mappedBy = "team", fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    val managers: MutableList<TeamManager> = mutableListOf()

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, name = "default_duty_color")
    var defaultDutyColor: Color = Color.RED

    @Column(nullable = false, name = "default_duty_name")
    var defaultDutyName: String = "OFF"

    @Column(nullable = false, name = "work_type")
    @Enumerated(EnumType.STRING)
    var workType: WorkType = WorkType.FLEXIBLE

    @OneToMany(mappedBy = "team", fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    val dutyTypes: MutableList<DutyType> = mutableListOf()

    @OneToMany(mappedBy = "team", fetch = FetchType.LAZY)
    val members: MutableList<Member> = mutableListOf()

    @Enumerated(EnumType.STRING)
    @Column(name = "duty_batch_template")
    var dutyBatchTemplate: DutyBatchTemplate? = null

    fun addMember(member: Member) {
        members.add(member)
        member.team = this
    }

    fun removeMember(member: Member) {
        members.remove(member)
        member.team = null
    }

    fun addDutyType(dutyName: String, dutyColor: Color? = null): DutyType {
        if (dutyTypes.any { it.name == dutyName }) {
            throw IllegalArgumentException("DutyType already exists")
        }

        val maxPosition = dutyTypes.maxOfOrNull { it.position } ?: -1

        val dutyType = DutyType(dutyName, maxPosition + 1, this)
        dutyColor?.let { dutyType.color = it }
        dutyTypes.add(dutyType)
        return dutyType
    }

    fun changeAdmin(member: Member?) {
        this.admin = member
    }

    fun isManager(login: LoginMember): Boolean {
        return isManager(login.id)
    }

    fun isManager(memberId: Long?): Boolean {
        if (memberId == null)
            return false
        return isAdmin(memberId) || managers.any { it.member.id == memberId }
    }

    fun isAdmin(memberId: Long?): Boolean {
        if (memberId == null)
            return false
        val adminId = admin?.id ?: return false
        return adminId == memberId
    }

    fun addManager(member: Member) {
        if (member.team != this)
            throw IllegalArgumentException("Member does not belong to this team")
        if (isManager(member.id ?: -1))
            throw IllegalArgumentException("Member is already a manager")
        this.managers.add(TeamManager(team = this, member = member))
    }

    fun removeManager(member: Member) {
        if (member.team != this)
            throw IllegalArgumentException("Member does not belong to this team")
        if (!isManager(member.id ?: -1))
            throw IllegalArgumentException("Member is not a manager")
        this.managers.removeIf { it.member == member }
    }

    override fun toString(): String {
        return "Team(name='$name', id=$id)"
    }


}
