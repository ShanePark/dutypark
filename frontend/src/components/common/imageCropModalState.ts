export interface CropCoordinates {
  width: number
  height: number
  top: number
  left: number
}

export interface CropResultLike {
  coordinates: CropCoordinates
  visibleArea: CropCoordinates
}

export interface CropSnapshot {
  coordinates: CropCoordinates
  visibleArea: CropCoordinates
}

const cropValueEpsilon = 0.001

export function createCropSnapshot(result: CropResultLike): CropSnapshot {
  return {
    coordinates: { ...result.coordinates },
    visibleArea: { ...result.visibleArea },
  }
}

export function hasCropChanged(
  initialSnapshot: CropSnapshot | null,
  currentResult: CropResultLike,
): boolean {
  if (!initialSnapshot) return true

  // The saved canvas is derived from coordinates. visibleArea only describes the cropper's
  // viewport and can legitimately differ after a zoom-in/zoom-out round trip.
  return !areCoordinatesEqual(initialSnapshot.coordinates, currentResult.coordinates)
}

function areCoordinatesEqual(first: CropCoordinates, second: CropCoordinates): boolean {
  return (
    Math.abs(first.width - second.width) <= cropValueEpsilon
    && Math.abs(first.height - second.height) <= cropValueEpsilon
    && Math.abs(first.top - second.top) <= cropValueEpsilon
    && Math.abs(first.left - second.left) <= cropValueEpsilon
  )
}
