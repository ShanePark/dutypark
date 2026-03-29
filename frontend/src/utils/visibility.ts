import { Eye, Users, House, Lock, type LucideIcon } from 'lucide-vue-next'
import { translateGlobal } from '@/i18n'

export type CalendarVisibility = 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'

export const VISIBILITY_ICONS: Record<CalendarVisibility, LucideIcon> = {
  PUBLIC: Eye,
  FRIENDS: Users,
  FAMILY: House,
  PRIVATE: Lock,
}

export const VISIBILITY_COLORS: Record<CalendarVisibility, string> = {
  PUBLIC: 'bg-dp-success',
  FRIENDS: 'bg-dp-accent',
  FAMILY: 'bg-dp-warning',
  PRIVATE: 'bg-dp-danger',
}

export function getVisibilityColor(visibility: string): string {
  return VISIBILITY_COLORS[visibility as CalendarVisibility] || 'bg-dp-accent'
}

export function getVisibilityIcon(visibility: string): LucideIcon {
  return VISIBILITY_ICONS[visibility as CalendarVisibility] || Eye
}

export function getVisibilityLabel(visibility: string): string {
  switch (visibility as CalendarVisibility) {
    case 'PUBLIC':
      return translateGlobal('visibility.labels.public')
    case 'FRIENDS':
      return translateGlobal('visibility.labels.friends')
    case 'FAMILY':
      return translateGlobal('visibility.labels.family')
    case 'PRIVATE':
      return translateGlobal('visibility.labels.private')
    default:
      return visibility
  }
}

export function getVisibilityDescription(visibility: string): string {
  switch (visibility as CalendarVisibility) {
    case 'PUBLIC':
      return translateGlobal('visibility.descriptions.public')
    case 'FRIENDS':
      return translateGlobal('visibility.descriptions.friends')
    case 'FAMILY':
      return translateGlobal('visibility.descriptions.family')
    case 'PRIVATE':
      return translateGlobal('visibility.descriptions.private')
    default:
      return translateGlobal('visibility.descriptions.fallback')
  }
}
