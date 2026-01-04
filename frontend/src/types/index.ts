// Auth types
export interface LoginMember {
  id: number
  email: string | null
  name: string
  teamId: number | null
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

// Attachment types - Full DTO from backend
export type AttachmentContextType = 'SCHEDULE' | 'PROFILE' | 'TEAM' | 'TODO'

export interface AttachmentDto {
  id: string
  contextType: AttachmentContextType
  contextId: string | null
  originalFilename: string
  contentType: string
  size: number
  hasThumbnail: boolean
  thumbnailUrl: string | null
  orderIndex: number
  createdAt: string
  createdBy: number
}

export interface CreateSessionRequest {
  contextType: AttachmentContextType
  targetContextId?: string | null
}

export interface CreateSessionResponse {
  sessionId: string
  expiresAt: string
  contextType: AttachmentContextType
}

export interface ReorderAttachmentsRequest {
  contextType: AttachmentContextType
  contextId: string
  orderedAttachmentIds: string[]
}

// Frontend attachment representation (normalized for UI)
export interface NormalizedAttachment {
  id: string
  name: string
  originalFilename: string
  contentType: string
  size: number
  thumbnailUrl: string | null
  downloadUrl: string | null
  isImage: boolean
  hasThumbnail: boolean
  orderIndex: number
  createdAt: string | null
  createdBy: number | null
  previewUrl: string | null
}

// Todo types
export interface Todo {
  id: string
  title: string
  content: string
  position: number | null
  status: TodoStatus
  createdDate: string
  completedDate: string | null
  // Frontend-only computed fields (for backward compatibility with existing components)
  hasAttachments?: boolean
  attachments?: Attachment[]
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

// Dashboard types - matches backend DTOs
export interface DashboardMemberDto {
  id: number | null
  name: string
  email?: string | null
  teamId?: number | null
  team?: string | null
  calendarVisibility: CalendarVisibility
  kakaoId?: string | null
  hasPassword?: boolean
  profilePhotoUrl?: string | null
}

export interface DashboardFriendDto {
  id: number | null
  name: string
  teamId?: number | null
  team?: string | null
  profilePhotoUrl?: string | null
}

export interface DashboardDutyDto {
  year: number
  month: number
  day: number
  dutyType: string | null
  dutyColor: string | null
  isOff: boolean
}

export interface DashboardScheduleDto {
  id: string
  content: string
  description: string
  position: number
  year: number
  month: number
  dayOfMonth: number
  startDateTime: string
  endDateTime: string
  isTagged: boolean
  owner: string
  tags: DashboardMemberDto[]
  visibility?: CalendarVisibility
  dateToCompare: string
  attachments: Attachment[]
  startDate: string
  daysFromStart: number
  endDate: string
  totalDays: number
  curDate: string
}

export interface DashboardFriendRequestDto {
  id: number
  fromMember: DashboardFriendDto
  toMember: DashboardFriendDto
  status: string
  createdAt: string | null
  requestType: 'FRIEND_REQUEST' | 'FAMILY_REQUEST'
}

export interface DashboardMyDetail {
  member: DashboardMemberDto
  duty: DashboardDutyDto | null
  schedules: DashboardScheduleDto[]
}

export interface DashboardFriendDetail {
  member: DashboardFriendDto
  duty: DashboardDutyDto | null
  schedules: DashboardScheduleDto[]
  isFamily: boolean
  pinOrder: number | null
}

export interface DashboardFriendInfo {
  friends: DashboardFriendDetail[]
  pendingRequestsTo: DashboardFriendRequestDto[]
  pendingRequestsFrom: DashboardFriendRequestDto[]
}

// Legacy Dashboard types (kept for compatibility)
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
export interface AdminMemberDto {
  id: number
  name: string
  email: string | null
  teamId: number | null
  teamName: string | null
  tokens: RefreshTokenDto[]
  profilePhotoUrl: string | null
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

// Duty Calendar types - matches backend DutyDto
export interface DutyCalendarDay {
  year: number
  month: number
  day: number
  dutyType: string | null
  dutyColor: string | null
  isOff: boolean
}

// Other duties response - for "view together" feature
export interface OtherDutyResponse {
  name: string
  duties: DutyCalendarDay[]
}

// Team DTO with duty types - matches backend TeamDto
export interface TeamDto {
  id: number
  name: string
  description: string | null
  workType: string
  dutyTypes: DutyTypeDto[]
  members: TeamMemberDto[]
  createdDate: string
  lastModifiedDate: string
  adminId: number | null
  adminName: string | null
  dutyBatchTemplate: DutyBatchTemplateDto | null
}

export interface DutyTypeDto {
  id: number | null
  name: string
  position: number
  color: string | null
}

export interface TeamMemberDto {
  id: number
  name: string
  email: string | null
  isManager: boolean
  isAdmin: boolean
  profilePhotoUrl: string | null
}

export interface DutyBatchTemplateDto {
  name: string
  label: string
  fileExtensions: string[]
}

// Holiday API response
export interface HolidayDto {
  dateName: string
  isHoliday: boolean
  localDate: string // ISO date string (YYYY-MM-DD)
}

// Team API types
export interface TeamDay {
  year: number
  month: number
  day: number
}

export interface MyTeamSummary {
  year: number
  month: number
  team: TeamDto | null
  teamDays: TeamDay[]
  isTeamManager: boolean
}

export interface SimpleMemberDto {
  id: number
  name: string
  profilePhotoUrl: string | null
}

export interface DutyByShift {
  dutyType: DutyTypeDto
  members: SimpleMemberDto[]
}

export interface TeamScheduleDto {
  id: string
  teamId: number
  content: string
  description: string
  position: number
  year: number
  month: number
  dayOfMonth: number
  daysFromStart: number | null
  totalDays: number | null
  startDateTime: string
  endDateTime: string
  createMember: string
  updateMember: string
}

export interface TeamScheduleSaveDto {
  id?: string
  teamId: number
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
}

// Member API types
export interface MemberDto {
  id: number | null
  name: string
  email: string | null
  teamId: number | null
  team: string | null
  calendarVisibility: CalendarVisibility
  kakaoId: string | null
  hasPassword: boolean
  profilePhotoUrl: string | null
}

export interface FriendDto {
  id: number | null
  name: string
  teamId: number | null
  team: string | null
  profilePhotoUrl: string | null
}

export interface DDayDto {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
  daysLeft: number
}

export interface DDaySaveDto {
  id?: number
  title: string
  date: string
  isPrivate: boolean
}

export interface RefreshTokenDto {
  memberName: string
  memberId: number
  validUntil: string
  lastUsed: string | null
  remoteAddr: string | null
  id: number
  token: string
  userAgent: RefreshTokenUserAgent | null
  isCurrentLogin: boolean | null
}

export interface RefreshTokenUserAgent {
  os: string
  browser: string
  device: string
}

// Page response type
export interface PageResponse<T> {
  content: T[]
  totalElements: number
  totalPages: number
  size: number
  number: number
  first: boolean
  last: boolean
}

// Duty Type management types
export interface DutyTypeCreateDto {
  teamId: number
  name: string
  color: string
}

export interface DutyTypeUpdateDto {
  id: number
  name: string
  color: string
}

// Duty Batch types
export interface DutyBatchResult {
  result: boolean
  errorMessage?: string
  startDate?: string
  endDate?: string
  workingDays: number
  offDays: number
}

export interface DutyBatchTeamResult {
  success: boolean
  message: string
  teamId?: number
  year?: number
  month?: number
  processedCount?: number
}

// Profile Photo types
export interface UpdateProfilePhotoRequest {
  sessionId: string
  attachmentId: string
}

export interface ProfilePhotoResponse {
  profilePhotoUrl: string | null
}
