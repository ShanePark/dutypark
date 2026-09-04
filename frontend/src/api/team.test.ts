import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: {
    post: vi.fn(),
  },
}))

import apiClient from './client'
import { teamApi } from './team'

describe('member team creation API contract', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('checks a team name through the authenticated team endpoint', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ data: 'OK' })

    await teamApi.checkTeamName('응급 팀')

    expect(apiClient.post).toHaveBeenCalledWith('/teams/check', { name: '응급 팀' })
  })

  it('creates a team through the authenticated team endpoint', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ data: { id: 7 } })

    await teamApi.createTeam({ name: '응급 팀', description: '' })

    expect(apiClient.post).toHaveBeenCalledWith('/teams', {
      name: '응급 팀',
      description: '',
    })
  })
})
