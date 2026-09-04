import { describe, expect, it } from 'vitest'
import teamManageView from './TeamManageView.vue?raw'

describe('team management service-admin access', () => {
  it('includes service admins in the existing team-admin UI permission', () => {
    expect(teamManageView).toContain('isAdmin.value = isAppAdmin.value ||')
    expect(teamManageView).toContain('team.value.adminId === loginId.value ||')
    expect(teamManageView).toContain('team.value.members.some(m => m.id === loginId.value && m.isManager)')
    expect(teamManageView).not.toContain('assignFirstAdmin')
    expect(teamManageView).not.toContain('canTransferAdminToMember')
  })
})
