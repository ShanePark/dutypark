function clamp(value: number) {
  return Math.max(0, Math.min(1, value))
}

export function getShowcaseProgress(
  showcaseTop: number,
  showcaseHeight: number,
  viewportHeight: number,
  featureCount: number,
) {
  const distance = showcaseHeight - viewportHeight
  if (featureCount <= 0 || distance <= 0) {
    return { activeIndex: 0, featureProgress: 0 }
  }

  const rawIndex = clamp(-showcaseTop / distance) * featureCount
  const activeIndex = Math.min(Math.floor(rawIndex), featureCount - 1)
  return { activeIndex, featureProgress: rawIndex - activeIndex }
}

export function getTransitionProgress(activeIndex: number, progress: number, featureCount: number) {
  return activeIndex < featureCount - 1 ? clamp((progress - 0.8) / 0.2) : 0
}

export function getScreenOpacity(index: number, activeIndex: number, progress: number, featureCount: number) {
  if (index < 0 || index >= featureCount) return 0
  // Keep an opaque base under the incoming screen, including at feature boundaries.
  if (index === activeIndex) return 1
  if (index === activeIndex + 1) return getTransitionProgress(activeIndex, progress, featureCount)
  return 0
}
