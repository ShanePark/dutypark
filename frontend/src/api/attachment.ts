import apiClient from './client'
import type {
  AttachmentContextType,
  AttachmentDto,
  CreateSessionRequest,
  CreateSessionResponse,
  NormalizedAttachment,
} from '@/types'

// Validation configuration
export const attachmentValidation = {
  maxFileSizeBytes: 50 * 1024 * 1024, // 50MB
  maxFileSizeLabel: '50MB',
  tooLargeMessage(filename?: string): string {
    const prefix = filename ? `${filename} 파일은` : '파일이'
    return `${prefix} 허용 용량(${this.maxFileSizeLabel})을 초과해 업로드할 수 없습니다.`
  },
  blockedExtensionMessage(filename?: string): string {
    const target = filename ? `${filename} 파일은` : '이 파일은'
    return `${target} 업로드할 수 없는 확장자입니다.`
  },
}

// Normalize AttachmentDto to frontend representation
export function normalizeAttachment(dto: AttachmentDto): NormalizedAttachment {
  return {
    id: dto.id,
    name: dto.originalFilename,
    originalFilename: dto.originalFilename,
    contentType: dto.contentType,
    size: dto.size,
    thumbnailUrl: dto.thumbnailUrl,
    downloadUrl: dto.id ? `/api/attachments/${dto.id}/download` : null,
    isImage: dto.contentType ? dto.contentType.startsWith('image/') : false,
    hasThumbnail: dto.hasThumbnail,
    orderIndex: dto.orderIndex,
    createdAt: dto.createdAt,
    createdBy: dto.createdBy,
    previewUrl: null,
  }
}

// Get download URL with optional inline parameter
export function getDownloadUrl(
  attachment: NormalizedAttachment | AttachmentDto,
  inline = false
): string | null {
  const id = attachment.id
  if (!id) return null
  const baseUrl = `/api/attachments/${id}/download`
  return inline ? `${baseUrl}?inline=true` : baseUrl
}

// Format bytes to human-readable string
export function formatBytes(bytes: number): string {
  if (!bytes) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${Math.round((bytes / Math.pow(k, i)) * 100) / 100} ${sizes[i]}`
}

// Get file extension from filename
export function getFileExtension(filename: string): string {
  if (!filename || filename.indexOf('.') === -1) {
    return ''
  }
  return filename.split('.').pop()?.toLowerCase() || ''
}

// Icon class mapping by extension
const ICON_BY_EXTENSION: Record<string, string> = {
  pdf: 'file-text',
  doc: 'file-text',
  docx: 'file-text',
  xls: 'file-spreadsheet',
  xlsx: 'file-spreadsheet',
  csv: 'file-spreadsheet',
  ppt: 'file-text',
  pptx: 'file-text',
  txt: 'file-text',
  md: 'file-text',
  json: 'file-code',
  xml: 'file-code',
  html: 'file-code',
  js: 'file-code',
  ts: 'file-code',
  mp3: 'file-audio',
  wav: 'file-audio',
  mp4: 'file-video',
  mov: 'file-video',
  avi: 'file-video',
  jpg: 'image',
  jpeg: 'image',
  png: 'image',
  gif: 'image',
  webp: 'image',
  svg: 'image',
  zip: 'file-archive',
  rar: 'file-archive',
  '7z': 'file-archive',
}

// Get icon name for attachment (lucide icon name)
export function getAttachmentIcon(
  attachment: NormalizedAttachment | AttachmentDto | { originalFilename?: string; contentType?: string }
): string {
  const filename = ('originalFilename' in attachment ? attachment.originalFilename : '') || ''
  const contentType = attachment.contentType || ''

  const ext = getFileExtension(filename)
  if (ext && ICON_BY_EXTENSION[ext]) {
    return ICON_BY_EXTENSION[ext]
  }

  if (contentType.startsWith('image/')) return 'image'
  if (contentType.startsWith('video/')) return 'file-video'
  if (contentType.startsWith('audio/')) return 'file-audio'
  if (contentType.includes('pdf')) return 'file-text'

  return 'file'
}

// Validate file before upload
export function validateFile(file: File): { valid: boolean; message?: string } {
  if (!file) {
    return { valid: false, message: '업로드할 파일을 찾지 못했습니다.' }
  }
  if (file.size > attachmentValidation.maxFileSizeBytes) {
    return {
      valid: false,
      message: attachmentValidation.tooLargeMessage(file.name),
    }
  }
  return { valid: true }
}

// Fetch image with authentication and return blob URL
export async function fetchAuthenticatedImage(url: string): Promise<string | null> {
  try {
    const response = await fetch(url, {
      credentials: 'include',
    })
    if (!response.ok) return null
    const blob = await response.blob()
    return URL.createObjectURL(blob)
  } catch {
    return null
  }
}

// API functions
export const attachmentApi = {
  /**
   * Create upload session
   */
  createSession: async (request: CreateSessionRequest): Promise<CreateSessionResponse> => {
    const response = await apiClient.post<CreateSessionResponse>('/attachments/sessions', request)
    return response.data
  },

  /**
   * Discard upload session
   */
  discardSession: async (sessionId: string): Promise<void> => {
    await apiClient.delete(`/attachments/sessions/${sessionId}`)
  },

  /**
   * List attachments for a context
   */
  listAttachments: async (
    contextType: AttachmentContextType,
    contextId: string
  ): Promise<NormalizedAttachment[]> => {
    const response = await apiClient.get<AttachmentDto[]>('/attachments', {
      params: { contextType, contextId },
    })
    return response.data.map(normalizeAttachment)
  },
}
