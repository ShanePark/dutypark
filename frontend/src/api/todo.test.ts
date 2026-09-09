import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: {
    delete: vi.fn(),
  },
}))

import apiClient from './client'
import { todoApi } from './todo'

describe('todo bulk cleanup API contract', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('sends the selected completed todo IDs and returns the deleted count', async () => {
    vi.mocked(apiClient.delete).mockResolvedValue({ data: { count: 2 } })

    await expect(todoApi.deleteCompletedTodos(['todo-1', 'todo-2'])).resolves.toEqual({ count: 2 })

    expect(apiClient.delete).toHaveBeenCalledWith('/todos/completed', {
      data: { todoIds: ['todo-1', 'todo-2'] },
    })
  })
})
