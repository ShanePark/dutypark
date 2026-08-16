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

export type GuideIconComponent = typeof BookOpen

/**
 * Closed vocabularies shared with the iOS client: the guide content file assigns these keys,
 * and each client maps them to its own assets. Only a design vocabulary change touches these
 * tables; guide content changes do not.
 */
export const GUIDE_ICONS: Record<string, GuideIconComponent> = {
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

export const GUIDE_FALLBACK_ICON: GuideIconComponent = BookOpen

export const GUIDE_TONE_CLASSES: Record<GuideTone, string> = {
  accent: 'text-dp-accent',
  accentLight: 'text-dp-accent-light',
  success: 'text-dp-success',
  warning: 'text-dp-warning',
  danger: 'text-dp-danger',
  neutral: 'text-dp-text-secondary',
  muted: 'text-dp-text-muted',
}

export const GUIDE_FALLBACK_TONE_CLASS = GUIDE_TONE_CLASSES.neutral

export function resolveGuideIcon(icon: string): GuideIconComponent {
  return GUIDE_ICONS[icon] ?? GUIDE_FALLBACK_ICON
}

export function resolveGuideToneClass(tone: string): string {
  return GUIDE_TONE_CLASSES[tone as GuideTone] ?? GUIDE_FALLBACK_TONE_CLASS
}
