// Auth types
export interface LoginMember {
  id: number
  email: string | null
  name: string
  teamId: number | null
  team: string | null
  isAdmin: boolean
  isImpersonating: boolean
  originalMemberId: number | null
}

export interface LoginDto {
  email: string
  password: string
  rememberMe: boolean
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
  dueDate: string | null
  isOverdue: boolean
  isTagged: boolean
  owner: string
  taggedByMember?: TodoTagMember | null
  tags: TodoTagMember[]
  // Frontend-only computed fields (for backward compatibility with existing components)
  hasAttachments?: boolean
  attachments?: Attachment[]
}

export interface TodoTagMember {
  id: number | null
  name: string
  teamId?: number | null
  team?: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export type TodoStatus = 'TODO' | 'IN_PROGRESS' | 'DONE'

// For kanban board
export interface TodoBoard {
  todo: Todo[]
  inProgress: Todo[]
  done: Todo[]
  counts: TodoCounts
}

export interface TodoCounts {
  todo: number
  inProgress: number
  done: number
  total: number
}

// API Request types
export interface TodoCreateRequest {
  title: string
  content?: string
  status?: TodoStatus
  dueDate?: string
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

export interface TodoUpdateRequest {
  title: string
  content: string
  status?: TodoStatus
  dueDate?: string | null
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

export interface TodoStatusChangeRequest {
  status: TodoStatus
  orderedIds?: string[]
}

export interface TodoPositionUpdateRequest {
  status: TodoStatus
  orderedIds: string[]
}

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

// Dashboard types - matches backend DTOs
export interface DashboardMemberDto {
  id: number | null
  name: string
  email?: string | null
  teamId?: number | null
  team?: string | null
  calendarVisibility: CalendarVisibility
  kakaoId?: string | null
  naverId?: string | null
  hasPassword?: boolean
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface DashboardFriendDto {
  id: number | null
  name: string
  teamId?: number | null
  team?: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
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
export interface ApiFieldError {
  field: string
  code: string
}

export interface ApiError {
  status: number
  code: string
  details?: Record<string, unknown> | null
  fieldErrors?: ApiFieldError[]
}

// Admin types
export interface AdminMemberDto {
  id: number
  name: string
  email: string | null
  teamId: number | null
  teamName: string | null
  tokens: RefreshTokenDto[]
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface AdminMemberDetailDto {
  id: number
  name: string
  email: string | null
  teamId: number | null
  teamName: string | null
  calendarVisibility: CalendarVisibility
  hasProfilePhoto: boolean
  profilePhotoVersion: number
  serviceAdmin: boolean
  teamAdmin: boolean
  teamManager: boolean
  auxiliaryAccount: boolean
  hasPassword: boolean
  authProviders: string[]
  createdDate: string
  lastModifiedDate: string
  activeSessionCount: number
  pushEnabledSessionCount: number
  lastActiveAt: string | null
  totalScheduleCount: number
  upcomingScheduleCount: number
  taggedScheduleCount: number
  totalTodoCount: number
  todoCount: number
  inProgressTodoCount: number
  doneTodoCount: number
  overdueTodoCount: number
  dueTodayTodoCount: number
  dDays: DDayDto[]
  friendCount: number
  familyCount: number
  pendingReceivedFriendRequestCount: number
  pendingSentFriendRequestCount: number
  managerCount: number
  managedMemberCount: number
  managerNames: string[]
  managedMemberNames: string[]
  totalNotificationCount: number
  unreadNotificationCount: number
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
  dutyTypeId: number | null
  dutyType: string | null
  dutyColor: string | null
  isOff: boolean
  source: DutySource
}

export type DutySource = 'OVERRIDE' | 'PATTERN' | 'LOCKED_PATTERN' | 'DEFAULT_OFF'

export type DutyPatternWeekday =
  | 'MONDAY'
  | 'TUESDAY'
  | 'WEDNESDAY'
  | 'THURSDAY'
  | 'FRIDAY'
  | 'SATURDAY'
  | 'SUNDAY'

export interface DutyPatternDto {
  weekdays: DutyPatternWeekday[]
  holidayOff: boolean
  effectiveFrom: string
}

export interface MyDutyPatternDto {
  configurable: boolean
  reason: string | null
  pattern: DutyPatternDto | null
  dutyType: DutyPatternDutyTypeDto | null
}

export interface DutyPatternDutyTypeDto {
  id: number
  name: string
  color: string | null
}

export interface DutyPatternUpdateDto {
  weekdays: DutyPatternWeekday[]
  holidayOff: boolean
}

// Other duties response - for "view together" feature
export interface OtherDutyResponse {
  memberId: number
  name: string
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
  duties: DutyCalendarDay[]
}

// Team DTO with duty types - matches backend TeamDto
export interface TeamDto {
  id: number
  name: string
  description: string | null
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
  hidden: boolean
}

export interface TeamMemberDto {
  id: number
  name: string
  email: string | null
  isManager: boolean
  isAdmin: boolean
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
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

export interface DutyByShift {
  dutyType: DutyTypeDto
  members: MemberPreviewDto[]
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
  naverId: string | null
  hasPassword: boolean
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface MemberPreviewDto {
  id: number | null
  name: string
  teamId: number | null
  team: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface MemberInviteCandidateDto {
  id: number | null
  name: string
  email: string | null
  teamId: number | null
  team: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface FriendDto {
  id: number
  name: string
  teamId: number | null
  team: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
  isFamily: boolean
  pinOrder: number | null
}

export interface TaggableFriend extends FriendDto {}

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
  createdDate: string | null
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
  errorCode?: string | null
  errorDetails?: Record<string, unknown> | null
  startDate?: string
  endDate?: string
  workingDays: number
  offDays: number
}

export interface DutyBatchTeamResult {
  result: boolean
  errorCode?: string | null
  errorDetails?: Record<string, unknown> | null
  startDate?: string
  endDate?: string
  dutyBatchResult: [string, DutyBatchResult][]
}

// Notification Types
export type NotificationType =
  | 'FRIEND_REQUEST_RECEIVED'
  | 'FRIEND_REQUEST_ACCEPTED'
  | 'FAMILY_REQUEST_RECEIVED'
  | 'FAMILY_REQUEST_ACCEPTED'
  | 'SCHEDULE_TAGGED'
  | 'TODO_TAGGED'
  | 'TODO_STATUS_TODO'
  | 'TODO_STATUS_IN_PROGRESS'
  | 'TODO_STATUS_DONE'

export type NotificationReferenceType = 'FRIEND_REQUEST' | 'SCHEDULE' | 'TODO' | 'MEMBER'

export interface NotificationActorSnapshotV1 {
  name: string | null
  hasProfilePhoto: boolean
  profilePhotoVersion: number
}

export type NotificationActorSnapshot = NotificationActorSnapshotV1

export interface UnknownNotificationPayloadV0 {
  version: 0
}

interface NotificationPayloadBaseV1 {
  version: 1
}

interface ActorNotificationPayloadV1 extends NotificationPayloadBaseV1 {
  actor: NotificationActorSnapshot
}

export interface FriendRequestReceivedPayloadV1 extends ActorNotificationPayloadV1 {}

export interface FriendRequestAcceptedPayloadV1 extends ActorNotificationPayloadV1 {}

export interface FamilyRequestReceivedPayloadV1 extends ActorNotificationPayloadV1 {}

export interface FamilyRequestAcceptedPayloadV1 extends ActorNotificationPayloadV1 {}

export interface ScheduleTaggedPayloadV1 extends ActorNotificationPayloadV1 {
  scheduleTitle: string
}

export interface TodoTaggedPayloadV1 extends ActorNotificationPayloadV1 {
  todoTitle: string
}

export interface TodoStatusTodoPayloadV1 extends ActorNotificationPayloadV1 {
  todoTitle: string
}

export interface TodoStatusInProgressPayloadV1 extends ActorNotificationPayloadV1 {
  todoTitle: string
}

export interface TodoStatusDonePayloadV1 extends ActorNotificationPayloadV1 {
  todoTitle: string
}

export interface NotificationPayloadByTypeV1 {
  FRIEND_REQUEST_RECEIVED: FriendRequestReceivedPayloadV1
  FRIEND_REQUEST_ACCEPTED: FriendRequestAcceptedPayloadV1
  FAMILY_REQUEST_RECEIVED: FamilyRequestReceivedPayloadV1
  FAMILY_REQUEST_ACCEPTED: FamilyRequestAcceptedPayloadV1
  SCHEDULE_TAGGED: ScheduleTaggedPayloadV1
  TODO_TAGGED: TodoTaggedPayloadV1
  TODO_STATUS_TODO: TodoStatusTodoPayloadV1
  TODO_STATUS_IN_PROGRESS: TodoStatusInProgressPayloadV1
  TODO_STATUS_DONE: TodoStatusDonePayloadV1
}

export interface NotificationPayloadByTypeV0 {
  FRIEND_REQUEST_RECEIVED: UnknownNotificationPayloadV0
  FRIEND_REQUEST_ACCEPTED: UnknownNotificationPayloadV0
  FAMILY_REQUEST_RECEIVED: UnknownNotificationPayloadV0
  FAMILY_REQUEST_ACCEPTED: UnknownNotificationPayloadV0
  SCHEDULE_TAGGED: UnknownNotificationPayloadV0
  TODO_TAGGED: UnknownNotificationPayloadV0
  TODO_STATUS_TODO: UnknownNotificationPayloadV0
  TODO_STATUS_IN_PROGRESS: UnknownNotificationPayloadV0
  TODO_STATUS_DONE: UnknownNotificationPayloadV0
}

export interface NotificationPayloadRegistry {
  0: NotificationPayloadByTypeV0
  1: NotificationPayloadByTypeV1
}

export type NotificationPayloadVersion = keyof NotificationPayloadRegistry
export type NotificationPayloadByVersion<V extends NotificationPayloadVersion> = NotificationPayloadRegistry[V]

export type FriendRequestReceivedPayload = NotificationPayloadByTypeV1['FRIEND_REQUEST_RECEIVED']
export type FriendRequestAcceptedPayload = NotificationPayloadByTypeV1['FRIEND_REQUEST_ACCEPTED']
export type FamilyRequestReceivedPayload = NotificationPayloadByTypeV1['FAMILY_REQUEST_RECEIVED']
export type FamilyRequestAcceptedPayload = NotificationPayloadByTypeV1['FAMILY_REQUEST_ACCEPTED']
export type ScheduleTaggedPayload = NotificationPayloadByTypeV1['SCHEDULE_TAGGED']
export type TodoTaggedPayload = NotificationPayloadByTypeV1['TODO_TAGGED']
export type TodoStatusTodoPayload = NotificationPayloadByTypeV1['TODO_STATUS_TODO']
export type TodoStatusInProgressPayload = NotificationPayloadByTypeV1['TODO_STATUS_IN_PROGRESS']
export type TodoStatusDonePayload = NotificationPayloadByTypeV1['TODO_STATUS_DONE']

export type NotificationPayloadV0 = NotificationPayloadByTypeV0[keyof NotificationPayloadByTypeV0]
export type NotificationPayloadV1 = NotificationPayloadByTypeV1[keyof NotificationPayloadByTypeV1]
export type NotificationPayload = {
  [V in NotificationPayloadVersion]: NotificationPayloadRegistry[V][keyof NotificationPayloadRegistry[V]]
}[NotificationPayloadVersion]

export type NotificationPayloadForType<T extends NotificationType> = {
  [V in NotificationPayloadVersion]: NotificationPayloadRegistry[V][T]
}[NotificationPayloadVersion]

export type NotificationPayloadForTypeAndVersion<
  T extends NotificationType,
  V extends NotificationPayloadVersion,
> = NotificationPayloadRegistry[V][T]

interface NotificationDtoBase<
  T extends NotificationType,
  V extends NotificationPayloadVersion,
> {
  id: string
  type: T
  referenceType: NotificationReferenceType | null
  referenceId: string | null
  actorId: number | null
  payload: NotificationPayloadForTypeAndVersion<T, V>
  isRead: boolean
  createdAt: string
}

export type NotificationDtoForTypeAndVersion<
  T extends NotificationType,
  V extends NotificationPayloadVersion,
> = NotificationDtoBase<T, V>

export type NotificationDto = {
  [T in NotificationType]: {
    [V in NotificationPayloadVersion]: NotificationDtoForTypeAndVersion<T, V>
  }[NotificationPayloadVersion]
}[NotificationType]

export interface NotificationCountDto {
  unreadCount: number
  totalCount: number
}

export interface PushNotificationPayload {
  type: NotificationType
  icon?: string | null
  badge?: string | null
  url?: string | null
  tag?: string | null
  notificationId?: string | null
  unreadCount?: number | null
  notification?: NotificationDto | null
}
