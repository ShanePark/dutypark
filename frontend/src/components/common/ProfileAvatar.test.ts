import { describe, expect, it } from 'vitest'
import profileAvatar from './ProfileAvatar.vue?raw'

const template = profileAvatar.slice(
  profileAvatar.indexOf('<template>'),
  profileAvatar.indexOf('<style'),
)

describe('ProfileAvatar image dragging', () => {
  it('disables native image dragging so pointer swipes can start on the photo', () => {
    expect(template).toMatch(/<img\b[^>]*\sdraggable="false"[^>]*>/)
  })
})
