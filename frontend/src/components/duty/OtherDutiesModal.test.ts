import { describe, expect, it } from 'vitest'
import otherDutiesModal from './OtherDutiesModal.vue?raw'

const template = otherDutiesModal.match(/<template>([\s\S]*?)<\/template>/)?.[1] ?? ''
const style = otherDutiesModal.match(/<style[^>]*>([\s\S]*?)<\/style>/)?.[1] ?? ''

function friendOptionOpening() {
  return template.match(
    /<button\s+v-for="friend in friends"[\s\S]*?(?=\s*<ProfileAvatar)/,
  )?.[0] ?? ''
}

describe('OtherDutiesModal friend options', () => {
  it('uses a semantic button with selection and disabled state', () => {
    const option = friendOptionOpening()

    expect(option).toMatch(/^<button/)
    expect(option).toContain('type="button"')
    expect(option).toContain(':aria-pressed="isSelected(friend.id)"')
    expect(option).toContain(':disabled="!isSelected(friend.id) && (isTeamless(friend) || !canSelectMore)"')
    expect(option).toContain('@click="handleToggle(friend.id)"')
  })

  it('lets state CSS own the surface instead of overriding hover with inline styles', () => {
    const option = friendOptionOpening()

    expect(option).not.toContain(':style')
    expect(option).not.toContain('backgroundColor')
    expect(option).toContain('friend-item')
    expect(option).toContain('friend-item-selected')
    expect(option).toContain('friend-item-disabled')
  })

  it('uses token surfaces and explicit state transitions for pointer hover', () => {
    expect(style).toMatch(
      /\.friend-item\s*\{[\s\S]*?background-color: var\(--dp-bg-secondary\);[\s\S]*?transition: background-color 0\.15s ease, border-color 0\.15s ease;/,
    )
    expect(style).not.toMatch(/transition:[^;]*,\s*color 0\.15s ease/)
    expect(style).toMatch(
      /@media \(hover: hover\) and \(pointer: fine\)[\s\S]*?\.friend-item:not\(\.friend-item-selected\):not\(\.friend-item-disabled\):hover\s*\{[\s\S]*?background-color: var\(--dp-bg-hover\);[\s\S]*?border-color: var\(--dp-accent-border\);[\s\S]*?box-shadow: none;/,
    )
    expect(style).not.toMatch(
      /@media \(hover: hover\) and \(pointer: fine\)[\s\S]*?\.friend-item:not\(\.friend-item-selected\):not\(\.friend-item-disabled\):hover\s*\{[\s\S]*?transform:/,
    )
  })

  it('keeps friend names in the primary text color during hover', () => {
    expect(style).not.toMatch(/\.friend-item-name\s*\{[\s\S]*?transition:/)
    expect(style).not.toMatch(
      /\.friend-item:not\(\.friend-item-selected\):not\(\.friend-item-disabled\):hover\s+\.friend-item-name\s*\{[\s\S]*?color:\s*var\(--dp-accent\);/,
    )
  })

  it('keeps selected hover accent, disables disabled hover, and exposes focus feedback', () => {
    expect(style).toMatch(
      /\.friend-item-selected\s*\{[\s\S]*?background-color: var\(--dp-accent-bg\);[\s\S]*?border-color: var\(--dp-accent-border\);/,
    )
    expect(style).toMatch(
      /@media \(hover: hover\) and \(pointer: fine\)[\s\S]*?\.friend-item-selected:hover\s*\{[\s\S]*?background-color: var\(--dp-accent-bg-hover\);/,
    )
    expect(style).toMatch(/\.friend-item-disabled\s*\{[\s\S]*?cursor: not-allowed;/)
    expect(style).not.toMatch(
      /@media \(hover: hover\) and \(pointer: fine\)[\s\S]*?\.friend-item-disabled:hover\s*\{/,
    )
    expect(style).toMatch(
      /\.friend-item:focus-visible\s*\{[\s\S]*?outline: 2px solid var\(--dp-accent\);[\s\S]*?outline-offset: 2px;/,
    )
  })

  it('removes option transitions when reduced motion is requested', () => {
    expect(style).toMatch(
      /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.friend-item,[\s\S]*?transition: none;/,
    )
    expect(style).not.toContain('.friend-item-name')
  })
})
