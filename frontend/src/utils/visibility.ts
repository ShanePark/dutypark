import { Eye, Users, House, Lock, type LucideIcon } from 'lucide-vue-next'

export type CalendarVisibility = 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'

export const VISIBILITY_ICONS: Record<CalendarVisibility, LucideIcon> = {
  PUBLIC: Eye,
  FRIENDS: Users,
  FAMILY: House,
  PRIVATE: Lock,
}

export const VISIBILITY_LABELS: Record<CalendarVisibility, string> = {
  PUBLIC: '전체공개',
  FRIENDS: '친구공개',
  FAMILY: '가족공개',
  PRIVATE: '나만보기',
}

export function getVisibilityIcon(visibility: string): LucideIcon {
  return VISIBILITY_ICONS[visibility as CalendarVisibility] || Eye
}

export function getVisibilityLabel(visibility: string): string {
  return VISIBILITY_LABELS[visibility as CalendarVisibility] || visibility
}
