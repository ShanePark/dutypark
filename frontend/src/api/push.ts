import apiClient from './client'

export interface PushSubscriptionKeys {
  p256dh: string
  auth: string
}

export interface PushSubscriptionRequest {
  endpoint: string
  keys: PushSubscriptionKeys
}

export const pushApi = {
  getVapidPublicKey: async (): Promise<string> => {
    const response = await apiClient.get<{ publicKey: string }>('/auth/push/vapid-public-key')
    return response.data.publicKey
  },

  isEnabled: async (): Promise<boolean> => {
    const response = await apiClient.get<{ enabled: boolean }>('/auth/push/enabled')
    return response.data.enabled
  },

  subscribe: async (subscription: PushSubscriptionRequest): Promise<boolean> => {
    const response = await apiClient.post<{ success: boolean }>('/auth/push/subscribe', subscription)
    return response.data.success
  },

  unsubscribe: async (): Promise<boolean> => {
    const response = await apiClient.post<{ success: boolean }>('/auth/push/unsubscribe')
    return response.data.success
  }
}
