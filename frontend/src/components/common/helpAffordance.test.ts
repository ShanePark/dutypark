import { describe, expect, it } from 'vitest'
import helpButton from './HelpButton.vue?raw'
import helpModal from './HelpModal.vue?raw'
import friendsView from '@/views/member/FriendsView.vue?raw'
import todoBoardView from '@/views/todo/TodoBoardView.vue?raw'

const helpScreens: Array<[string, string]> = [
  ['friends', friendsView],
  ['todo board', todoBoardView],
]

describe('help affordance', () => {
  it('names help with the information glyph rather than a question mark', () => {
    expect(helpButton).toContain("import { Info } from 'lucide-vue-next'")
    expect(helpButton).toContain('<Info />')
    expect(helpButton).not.toContain('HelpCircle')
  })

  it('keeps the entry point on a full touch target', () => {
    expect(helpButton).toContain('min-height: 44px')
  })

  it('opens every help panel through the shared button and modal', () => {
    for (const [name, view] of helpScreens) {
      expect(view, name).toContain('<HelpButton')
      expect(view, name).toContain('<HelpModal')
      expect(view, name).toContain('<HelpSection')
      expect(view, name).toContain('<HelpNote')
    }
  })

  it('leaves no screen with its own help chrome', () => {
    for (const [name, view] of helpScreens) {
      expect(view, name).not.toContain('HelpCircle')
      expect(view, name).not.toContain('help-btn')
      expect(view, name).not.toContain('help-section')
      expect(view, name).not.toContain('help-tips-list')
    }
  })

  it('gives the panel the same header on every screen', () => {
    expect(helpModal).toContain('class="modal-header"')
    expect(helpModal).toContain('<Info class="help-modal-title-icon" />')
    expect(helpModal).toContain("t('common.actions.close')")
  })
})
