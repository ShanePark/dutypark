// Auth types
export interface LoginMember {
  id: number
  email: string | null
  name: string
  team: string | null
  isAdmin: boolean
}

export interface LoginDto {
  email: string
  password: string
  rememberMe: boolean
}

export interface LoginResponse {
  token?: string
  member: LoginMember
}

// Member types
export interface Member {
  id: number
  name: string
  email: string
  team?: Team
  calendarVisibility: CalendarVisibility
}

export type CalendarVisibility = 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'

// Team types
export interface Team {
  id: number
  name: string
  description?: string
}

export interface DutyType {
  id: number
  name: string
  shortName: string
  color: string
  position: number
}

// Duty types
export interface Duty {
  id: number
  date: string
  dutyType: DutyType
  member: Member
}

// Schedule types
export interface Schedule {
  id: string
  date: string
  content: string
  startTime?: string
  endTime?: string
  visibility: CalendarVisibility
  position: number
  attachments: Attachment[]
  tags: ScheduleTag[]
}

export interface ScheduleTag {
  memberId: number
  memberName: string
}

export interface Attachment {
  id: string
  originalFileName: string
  thumbnailAvailable: boolean
}

// Todo types
export interface Todo {
  id: string
  title: string
  content?: string
  status: TodoStatus
  position: number
  createdDate: string
  completedAt?: string
  attachments: Attachment[]
}

export type TodoStatus = 'ACTIVE' | 'COMPLETED'

// D-Day types
export interface DDay {
  id: number
  title: string
  date: string
  isPrivate: boolean
}

// Friend types
export interface Friend {
  id: number
  name: string
  team?: string
  isFamily: boolean
  isPinned: boolean
}

export interface FriendRequest {
  id: number
  name: string
  team?: string
  createdAt: string
}

// Dashboard types
export interface DashboardMyInfo {
  member: Member
  duty?: Duty
  todaySchedules: Schedule[]
}

export interface DashboardFriendsInfo {
  friends: Friend[]
  pendingRequests: FriendRequest[]
  receivedRequests: FriendRequest[]
}

// Pagination types
export interface Page<T> {
  content: T[]
  totalElements: number
  totalPages: number
  size: number
  number: number
  first: boolean
  last: boolean
}

// API Response types
export interface ApiError {
  status: number
  message: string
  code?: string
}

// Admin types
export interface AdminMember {
  id: number
  name: string
  tokens: RefreshToken[]
}

export interface RefreshToken {
  memberId: number
  lastUsed: string
  remoteAddr: string
  userAgent?: UserAgentInfo
}

export interface UserAgentInfo {
  device: string
  browser: string
}

export interface SimpleTeam {
  id: number
  name: string
  description: string
  memberCount: number
}

export interface TeamCreateDto {
  name: string
  description: string
}

export type TeamNameCheckResult = 'OK' | 'TOO_SHORT' | 'TOO_LONG' | 'DUPLICATED'
