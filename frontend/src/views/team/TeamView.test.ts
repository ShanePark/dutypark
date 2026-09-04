import { describe, expect, it } from 'vitest'
import teamView from './TeamView.vue?raw'

describe('team self-service creation', () => {
  it('offers a create-team action from the no-team state', () => {
    expect(teamView).toContain("t('team.view.emptyDescription')")
    expect(teamView).toContain('@click="openCreateTeamModal"')
    expect(teamView).toContain("t('team.view.actions.createTeam')")
  })

  it('checks the name before creating a member-owned team', () => {
    expect(teamView).toContain('await teamApi.checkTeamName(requestedName)')
    expect(teamView).toContain('await teamApi.createTeam(createDto)')
    expect(teamView).toContain('await authStore.checkAuth()')
    expect(teamView).toContain("error)?.code === 'team.name.duplicated'")
    expect(teamView).toContain("nameDuplicated")
    expect(teamView).toContain('router.push(`/team/manage/${response.data.id}`)')
  })

  it('does not expose a join-request action', () => {
    expect(teamView).not.toContain("t('team.view.actions.requestJoin')")
  })
})
