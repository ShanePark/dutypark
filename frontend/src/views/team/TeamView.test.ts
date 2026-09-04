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

  it('keeps the server auth refresh authoritative after team creation', () => {
    const createFlow = teamView.slice(
      teamView.indexOf('async function handleCreateTeam()'),
      teamView.indexOf('function goToMemberDuty('),
    )
    const refreshFlowStart = createFlow.indexOf('try {\n      await authStore.checkAuth()')
    const refreshFlowEnd = createFlow.indexOf('toastSuccess(', refreshFlowStart)
    const refreshFlow = createFlow.slice(refreshFlowStart, refreshFlowEnd)

    expect(createFlow).toContain('const memberBeforeRefresh = authStore.user')
    expect(createFlow).not.toContain('authStore.user?.teamId !== createdTeamId')
    expect(refreshFlow).not.toContain('memberBeforeRefresh')
    expect(refreshFlow).not.toContain('authStore.setUser(')
  })

  it('associates the create-team dialog and its controls for assistive technology', () => {
    const createModal = teamView.slice(
      teamView.indexOf('<BaseModal\n      :is-open="showCreateTeamModal"'),
      teamView.indexOf('<BaseModal\n      :is-open="showScheduleModal"'),
    )

    expect(createModal).toContain(':aria-labelledby="createTeamModalTitleId"')
    expect(createModal).toContain('<h2 :id="createTeamModalTitleId">')
    expect(createModal).toContain(':aria-label="t(\'common.actions.close\')"')
    expect(createModal).toContain('for="new-team-name"')
    expect(createModal).toContain('id="new-team-name"')
    expect(createModal).toContain('for="new-team-description"')
    expect(createModal).toContain('id="new-team-description"')
  })

  it('does not expose a join-request action', () => {
    expect(teamView).not.toContain("t('team.view.actions.requestJoin')")
  })
})
