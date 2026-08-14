import apiClient from './client'
import type {
  Todo,
  TodoBoard,
  TodoCreateRequest,
  TodoUpdateRequest,
  TodoStatusChangeRequest,
  TodoPositionUpdateRequest,
} from '@/types'

export interface LegacyTodoRequest {
  title: string
  content: string
  status?: string
  dueDate?: string | null
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

export const todoApi = {
  completeTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/complete`)
    return response.data
  },

  reopenTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/reopen`)
    return response.data
  },

  getBoard: async (): Promise<TodoBoard> => {
    const response = await apiClient.get<TodoBoard>('/todos/board')
    return response.data
  },

  changeStatus: async (id: string, request: TodoStatusChangeRequest): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/status`, request)
    return response.data
  },

  untagSelf: async (id: string): Promise<void> => {
    await apiClient.delete(`/todos/${id}/tags`)
  },

  updatePositions: async (request: TodoPositionUpdateRequest): Promise<void> => {
    await apiClient.patch('/todos/positions', request)
  },

  createTodo: async (request: TodoCreateRequest | LegacyTodoRequest): Promise<Todo> => {
    const response = await apiClient.post<Todo>('/todos', request)
    return response.data
  },

  updateTodo: async (id: string, request: TodoUpdateRequest | LegacyTodoRequest): Promise<Todo> => {
    const response = await apiClient.put<Todo>(`/todos/${id}`, request)
    return response.data
  },

  deleteTodo: async (id: string): Promise<void> => {
    await apiClient.delete(`/todos/${id}`)
  },
}
