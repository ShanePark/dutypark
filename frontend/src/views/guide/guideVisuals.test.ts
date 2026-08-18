import { describe, expect, it } from 'vitest'
import {
  Bell,
  BookOpen,
  Building2,
  Calendar,
  CalendarCheck,
  Camera,
  ClipboardList,
  Eye,
  FileSpreadsheet,
  Home,
  Link,
  Lock,
  Palette,
  Pencil,
  Pin,
  Plus,
  Search,
  Settings,
  Shield,
  Smartphone,
  Sparkles,
  Sun,
  Trash2,
  UserCog,
  UserPlus,
  Users,
} from 'lucide-vue-next'
import type { GuideTone } from '@/api/publicContent'
import {
  GUIDE_ICONS,
  GUIDE_TONE_CLASSES,
  resolveGuideIcon,
  resolveGuideToneClass,
  type GuideIconComponent,
} from './guideVisuals'

/**
 * The shared vocabulary contract: these 25 icon keys and 7 tone keys are what the guide content
 * file may assign, so every one of them must resolve here instead of hitting the fallback.
 */
const contractIcons: Record<string, GuideIconComponent> = {
  home: Home,
  calendar: Calendar,
  calendarCheck: CalendarCheck,
  building: Building2,
  settings: Settings,
  users: Users,
  personAdd: UserPlus,
  userCog: UserCog,
  pencil: Pencil,
  spreadsheet: FileSpreadsheet,
  plus: Plus,
  sparkles: Sparkles,
  eye: Eye,
  checklist: ClipboardList,
  search: Search,
  palette: Palette,
  sun: Sun,
  bell: Bell,
  pin: Pin,
  trash: Trash2,
  camera: Camera,
  shield: Shield,
  phone: Smartphone,
  link: Link,
  lock: Lock,
}

const contractToneClasses: Record<GuideTone, string> = {
  accent: 'text-dp-accent',
  accentLight: 'text-dp-accent-light',
  success: 'text-dp-success',
  warning: 'text-dp-warning',
  danger: 'text-dp-danger',
  neutral: 'text-dp-text-secondary',
  muted: 'text-dp-text-muted',
}

describe('guideVisuals', () => {
  it('maps exactly the 25 contract icon keys', () => {
    expect(Object.keys(contractIcons)).toHaveLength(25)
    expect(Object.keys(GUIDE_ICONS).sort()).toEqual(Object.keys(contractIcons).sort())
  })

  it('resolves every contract icon key to its component without falling back', () => {
    for (const [key, component] of Object.entries(contractIcons)) {
      expect(resolveGuideIcon(key), `icon key ${key}`).toBe(component)
      expect(resolveGuideIcon(key), `icon key ${key}`).not.toBe(BookOpen)
    }
  })

  it('maps exactly the 7 contract tone keys', () => {
    expect(Object.keys(contractToneClasses)).toHaveLength(7)
    expect(Object.keys(GUIDE_TONE_CLASSES).sort()).toEqual(
      Object.keys(contractToneClasses).sort(),
    )
  })

  it('resolves every contract tone key to its class', () => {
    for (const [key, className] of Object.entries(contractToneClasses)) {
      expect(resolveGuideToneClass(key), `tone key ${key}`).toBe(className)
    }
  })

  it('falls back to the book icon for an unknown icon key', () => {
    expect(resolveGuideIcon('unknown-icon')).toBe(BookOpen)
  })

  it('falls back to the neutral class for an unknown tone key', () => {
    expect(resolveGuideToneClass('unknown-tone')).toBe(contractToneClasses.neutral)
  })
})
