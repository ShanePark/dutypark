import { describe, expect, it } from 'vitest'
import { buildDisplayTagMembers } from './tagMembers'

const owner = { id: 8, name: 'Owner', hasProfilePhoto: true, profilePhotoVersion: 2 }

describe('schedule display tag members', () => {
  it('puts an already tagged owner first and marks only that member as the owner', () => {
    const result = buildDisplayTagMembers({
      itemKey: 'schedule', isTagged: true, taggedByMember: owner,
      tags: [{ id: 2, name: 'Friend' }, owner, { id: 1, name: 'Viewer' }], excludeMemberId: 1,
    })
    expect(result.map(member => member.id)).toEqual([8, 2])
    expect(result.map(member => !!member.isOwner)).toEqual([true, false])
    expect(result[0]).toMatchObject(owner)
  })

  it('marks an inserted owner or a legacy name-only owner', () => {
    for (const ownership of [{ taggedByMember: owner }, { owner: 'Owner' }, { taggedBy: 'Owner' }]) {
      const result = buildDisplayTagMembers({ itemKey: 'schedule', isTagged: true, ...ownership, tags: [{ id: 2, name: 'Friend' }] })
      expect(result.map(member => !!member.isOwner)).toEqual([true, false])
      expect(result[0]?.name).toBe('Owner')
    }
  })

  it('does not mark participants as owners or add a new chip to an authored schedule', () => {
    const result = buildDisplayTagMembers({ itemKey: 'schedule', isTagged: false, owner: 'Owner', tags: [{ id: 2, name: 'Friend' }] })
    expect(result).toHaveLength(1)
    expect(result[0]?.isOwner).not.toBe(true)
  })
})
