import apiClient from './client'
import type { BlockedMember } from '@/types/block'

/**
 * Block API Client
 */
export const blockApi = {
  /**
   * Block a member. Idempotent.
   */
  block: async (memberId: number): Promise<void> => {
    await apiClient.post(`/blocks/${memberId}`)
  },

  /**
   * Unblock a member. Idempotent.
   */
  unblock: async (memberId: number): Promise<void> => {
    await apiClient.delete(`/blocks/${memberId}`)
  },

  /**
   * Get every member I blocked
   */
  getBlockedMembers: async (): Promise<BlockedMember[]> => {
    const response = await apiClient.get<BlockedMember[]>('/blocks')
    return response.data
  },
}
