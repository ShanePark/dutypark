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

  it('sends all selected completed todo IDs and returns both cleanup counts', async () => {
    vi.mocked(apiClient.delete).mockResolvedValue({ data: { deletedCount: 2, untaggedCount: 1 } })

    await expect(todoApi.deleteCompletedTodos(['todo-1', 'todo-2', 'todo-3'])).resolves.toEqual({
      deletedCount: 2,
      untaggedCount: 1,
    })

    expect(apiClient.delete).toHaveBeenCalledWith('/todos/completed', {
      data: { todoIds: ['todo-1', 'todo-2', 'todo-3'] },
    })
  })
})
