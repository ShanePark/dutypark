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
  // ===== Legacy API (backward compatible) =====

  /**
   * Get TODO status list (formerly ACTIVE)
   * @deprecated Use getBoard() for kanban board
   */
  getActiveTodos: async (): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos')
    return response.data
  },

  /**
   * Get DONE status list (formerly COMPLETED)
   * @deprecated Use getBoard() for kanban board
   */
  getCompletedTodos: async (): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos/completed')
    return response.data
  },

  /**
   * Update positions (legacy, TODO status only)
   * @deprecated Use updatePositions() for kanban board
   */
  updatePositionsLegacy: async (ids: string[]): Promise<void> => {
    await apiClient.patch('/todos/position', ids)
  },

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

  // ===== New API (for kanban board) =====

  /**
   * Get full kanban board
   */
  getBoard: async (): Promise<TodoBoard> => {
    const response = await apiClient.get<TodoBoard>('/todos/board')
    return response.data
  },

  /**
   * Get list by specific status
   */
  getByStatus: async (status: string): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>(`/todos/status/${status}`)
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

  // ===== Due Date API =====

  /**
   * Get todos by month (for calendar integration)
   */
  getTodosByMonth: async (year: number, month: number): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos/calendar', {
      params: { year, month },
    })
    return response.data
  },

  /**
   * Get todos by specific date
   */
  getTodosByDate: async (date: string): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos/due', {
      params: { date },
    })
    return response.data
  },

  /**
   * Get overdue todos
   */
  getOverdueTodos: async (): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos/overdue')
    return response.data
  },

  // ===== Common API =====

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
