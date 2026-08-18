export function createLatestRequestTracker() {
  let latestRequestId = 0

  return {
    start(): number {
      latestRequestId += 1
      return latestRequestId
    },
    isLatest(requestId: number): boolean {
      return requestId === latestRequestId
    },
  }
}

export function lastValidPage(requestedPage: number, totalPages: number): number {
  return Math.min(requestedPage, Math.max(totalPages - 1, 0))
}
