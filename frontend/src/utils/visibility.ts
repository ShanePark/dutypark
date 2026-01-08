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
  PRIVATE: '비공개',
}

export const VISIBILITY_COLORS: Record<CalendarVisibility, string> = {
  PUBLIC: 'bg-green-500',
  FRIENDS: 'bg-blue-500',
  FAMILY: 'bg-orange-500',
  PRIVATE: 'bg-red-500',
}

export function getVisibilityColor(visibility: string): string {
  return VISIBILITY_COLORS[visibility as CalendarVisibility] || 'bg-blue-500'
}

export function getVisibilityIcon(visibility: string): LucideIcon {
  return VISIBILITY_ICONS[visibility as CalendarVisibility] || Eye
}

export function getVisibilityLabel(visibility: string): string {
  return VISIBILITY_LABELS[visibility as CalendarVisibility] || visibility
}
