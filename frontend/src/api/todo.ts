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
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

export const todoApi = {
  /**
   * Complete task (TODO/IN_PROGRESS -> DONE)
   */
  completeTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/complete`)
    return response.data
  },

  /**
   * Reopen task (DONE -> TODO)
   */
  reopenTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/reopen`)
    return response.data
  },

  /**
   * Get full kanban board
   */
  getBoard: async (): Promise<TodoBoard> => {
    const response = await apiClient.get<TodoBoard>('/todos/board')
    return response.data
  },

  /**
   * Change status (kanban column move)
   */
  changeStatus: async (id: string, request: TodoStatusChangeRequest): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/status`, request)
    return response.data
  },

  /**
   * Update positions by status
   */
  updatePositions: async (request: TodoPositionUpdateRequest): Promise<void> => {
    await apiClient.patch('/todos/positions', request)
  },

  /**
   * Create todo
   */
  createTodo: async (request: TodoCreateRequest | LegacyTodoRequest): Promise<Todo> => {
    const response = await apiClient.post<Todo>('/todos', request)
    return response.data
  },

  /**
   * Update todo
   */
  updateTodo: async (id: string, request: TodoUpdateRequest | LegacyTodoRequest): Promise<Todo> => {
    const response = await apiClient.put<Todo>(`/todos/${id}`, request)
    return response.data
  },

  /**
   * Delete todo
   */
  deleteTodo: async (id: string): Promise<void> => {
    await apiClient.delete(`/todos/${id}`)
  },
}
