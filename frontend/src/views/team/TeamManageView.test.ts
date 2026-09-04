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
})
