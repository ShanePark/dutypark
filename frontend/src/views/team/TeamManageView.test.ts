import { describe, expect, it } from 'vitest'
import teamManageView from './TeamManageView.vue?raw'

describe('team management service-admin access', () => {
  it('includes service admins in the existing team-admin UI permission', () => {
    expect(teamManageView).toContain('isAdmin.value = isAppAdmin.value ||')
    expect(teamManageView).toContain('team.value.adminId === loginId.value ||')
    expect(teamManageView).toContain('team.value.members.some(m => m.id === loginId.value && m.isManager)')
  })

  it('offers service admins a direct team-lead action for members when the team has no lead', () => {
    expect(teamManageView).toMatch(
      /const canAssignFirstAdmin = computed\(\(\) => isAppAdmin\.value && team\.value\?\.adminId === null\)/,
    )
    expect(teamManageView).toMatch(
      /<div v-if="!member\.isManager" class="flex items-center justify-center gap-1">[\s\S]*?v-if="canAssignFirstAdmin && !member\.isAdmin"[\s\S]*?@click="changeAdmin\(member\)"[\s\S]*?t\('team\.manage\.actions\.assignAdmin'\)[\s\S]*?@click="assignManager\(member\)"/,
    )
    expect(teamManageView).toContain('await teamApi.changeAdmin(teamId, member?.id ?? null)')
    expect(teamManageView).toContain("? 'team.manage.messages.assignAdminConfirm'")
    expect(teamManageView).toContain("canAssignFirstAdmin ? 'team.manage.actions.assignAdmin' : 'team.manage.actions.transferAdmin'")
  })

  it('keeps the existing manager and lead-transfer actions for teams that already have a lead', () => {
    expect(teamManageView).toContain('v-if="!member.isManager"')
    expect(teamManageView).toContain('@click="assignManager(member)"')
    expect(teamManageView).toContain('v-else-if="member.isManager && !member.isAdmin"')
    expect(teamManageView).toContain('@click="unAssignManager(member)"')
    expect(teamManageView).toContain('@click="changeAdmin(member)"')
  })

  it('uses a clearly labelled manager action instead of a standalone plus icon', () => {
    expect(teamManageView).toContain('UserCog')
    expect(teamManageView).toMatch(
      /@click="assignManager\(member\)"[\s\S]*?t\('team\.manage\.actions\.assignManager'\)/,
    )
    expect(teamManageView).not.toMatch(
      /@click="assignManager\(member\)"[\s\S]*?<Plus class="w-5 h-5 mx-auto" \/>/,
    )
  })

  it('keeps management actions consistent with the shared focus and touch target styles', () => {
    expect(teamManageView).toContain('min-h-11')
    expect(teamManageView).toContain('focus-visible:ring-2')
    expect(teamManageView).toContain('bg-dp-accent-soft')
    expect(teamManageView).toContain('bg-dp-danger-soft')
  })

  it('renders compact duty type rows with exact color previews and hidden types grouped last', () => {
    expect(teamManageView).toContain('groupDutyTypesForManagement')
    expect(teamManageView).toContain('v-for="(dutyType, index) in displayedDutyTypes"')
    expect(teamManageView).toContain('backgroundColor: dutyType.color ||')
    expect(teamManageView).toContain('isLightColor(dutyType.color)')
    expect(teamManageView).not.toMatch(/v-if="hasDutyType" class="overflow-x-auto"/)
    expect(teamManageView).not.toContain("t('team.manage.fields.status')")
    expect(teamManageView).not.toContain("t('team.manage.labels.visible')")
    expect(teamManageView).not.toContain("t('team.manage.labels.offDuty')")
  })

  it('limits admin-only actions to the actual team lead or a service admin', () => {
    expect(teamManageView).toMatch(
      /const canAdminTeam = computed\(\(\) => isAppAdmin\.value \|\| \(team\.value\?\.adminId != null && team\.value\.adminId === loginId\.value\)\)/,
    )
    expect(teamManageView).toContain('<template v-if="!canAdminTeam">')
    expect(teamManageView).not.toContain('<template v-if="!isAdmin">')
    expect(teamManageView).toContain('v-if="canAdminTeam && !member.isAdmin"')
    expect(teamManageView).not.toContain('v-if="isAdmin && !member.isAdmin"')
    expect(teamManageView.match(/v-if="canAdminTeam && team\.adminId && loginId !== team\.adminId"/g)).toHaveLength(2)
  })

  it('does not offer removing the team lead', () => {
    const removeButtons = teamManageView.match(/<button\s+v-if="!member\.isAdmin"\s+type="button"\s+@click="removeMember\(member\.id\)"/g)
    expect(removeButtons).toHaveLength(2)
    expect(teamManageView.match(/@click="removeMember\(member\.id\)"/g)).toHaveLength(2)
  })

  it('shows the translated server reason when removing a member fails', () => {
    const removeFlow = teamManageView.slice(
      teamManageView.indexOf('async function removeMember('),
      teamManageView.indexOf('async function assignManager('),
    )
    expect(removeFlow).toContain(
      "showError(resolveApiErrorMessage(error, { fallbackKey: 'team.manage.messages.removeMemberFailed' }, t))",
    )
  })
})
