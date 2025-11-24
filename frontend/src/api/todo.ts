import apiClient from './client'
import type { Todo } from '@/types'

export interface TodoRequest {
  title: string
  content: string
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

export const todoApi = {
  /**
   * 활성 Todo 목록 조회
   */
  getActiveTodos: async (): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos')
    return response.data
  },

  /**
   * 완료된 Todo 목록 조회
   */
  getCompletedTodos: async (): Promise<Todo[]> => {
    const response = await apiClient.get<Todo[]>('/todos/completed')
    return response.data
  },

  /**
   * Todo 생성
   */
  createTodo: async (request: TodoRequest): Promise<Todo> => {
    const response = await apiClient.post<Todo>('/todos', request)
    return response.data
  },

  /**
   * Todo 수정
   */
  updateTodo: async (id: string, request: TodoRequest): Promise<Todo> => {
    const response = await apiClient.put<Todo>(`/todos/${id}`, request)
    return response.data
  },

  /**
   * Todo 순서 변경 (드래그 정렬)
   */
  updatePositions: async (ids: string[]): Promise<void> => {
    await apiClient.patch('/todos/position', ids)
  },

  /**
   * Todo 완료 처리
   */
  completeTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/complete`)
    return response.data
  },

  /**
   * Todo 재오픈 (완료 취소)
   */
  reopenTodo: async (id: string): Promise<Todo> => {
    const response = await apiClient.patch<Todo>(`/todos/${id}/reopen`)
    return response.data
  },

  /**
   * Todo 삭제
   */
  deleteTodo: async (id: string): Promise<void> => {
    await apiClient.delete(`/todos/${id}`)
  },
}
