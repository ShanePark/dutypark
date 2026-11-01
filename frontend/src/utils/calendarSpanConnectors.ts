export interface CalendarSpanAnchor {
  day: number
  key: string
  part: number
  left: number
  right: number
  y: number
  color: string
  paddingLeft: number
  paddingRight: number
  thickness: number
}
export interface CalendarSpanConnector {
  from: number
  to: number
  inset: number
  path: string
  startColor: string
  endColor: string
  x1: number
  x2: number
}
export function buildCalendarSpanConnectors(anchors: CalendarSpanAnchor[]): CalendarSpanConnector[] {
  const byDayAndKey = new Map(anchors.map((anchor, index) => [JSON.stringify([anchor.day, anchor.key]), index]))
  const connectors: CalendarSpanConnector[] = []
  anchors.forEach((anchor, from) => {
    if (anchor.day % 7 === 6) return
    const to = byDayAndKey.get(JSON.stringify([anchor.day + 1, anchor.key]))
    if (to === undefined) return
    const next = anchors[to]!
    if (next.part !== anchor.part + 1) return
    // Half the stroke also fits in the empty edge strip, keeping steep curves
    // away from titles and tags without moving any content.
    const inset = Math.max(0, Math.min(
      12, (anchor.right - anchor.left) / 4, (next.right - next.left) / 4,
      anchor.paddingRight - anchor.thickness / 2,
      next.paddingLeft - next.thickness / 2,
    ))
    const x1 = anchor.right - inset
    const x2 = next.left + inset
    const middle = (x1 + x2) / 2
    const path = Math.abs(anchor.y - next.y) < 0.1
      ? `M ${x1} ${anchor.y} L ${x2} ${next.y}`
      : `M ${x1} ${anchor.y} C ${middle} ${anchor.y} ${middle} ${next.y} ${x2} ${next.y}`
    connectors.push({ from, to, inset, path, x1, x2, startColor: anchor.color, endColor: next.color })
  })
  return connectors
}

export interface CalendarSpanPath {
  path: string
  x1: number
  x2: number
  thickness: number
  stops: Array<{ offset: number; color: string }>
  clipLeft: number
  clipRight: number
}

export interface CalendarSpanUnderline extends CalendarSpanAnchor {
  barLeft: number
  barRight: number
  starts?: boolean
  ends?: boolean
}

export function buildCalendarSpanPaths(anchors: CalendarSpanUnderline[]): CalendarSpanPath[] {
  const joins = buildCalendarSpanConnectors(anchors)
  const outgoing = new Map(joins.map(join => [join.from, join]))
  const incoming = new Set(joins.map(join => join.to))
  const paths: CalendarSpanPath[] = []
  anchors.forEach((first, index) => {
    if (incoming.has(index)) return
    const x1 = first.barLeft + (first.starts ? first.thickness / 2 : 0)
    let current = first
    let currentIndex = index
    let path = `M ${x1} ${first.y}`
    const colors = [{ x: x1, color: first.color }]
    let join = outgoing.get(currentIndex)
    while (join) {
      const next = anchors[join.to]!
      path += ` L ${join.x1} ${current.y} ${join.path.replace(/^M \S+ \S+ /, '')}`
      colors.push({ x: join.x1, color: current.color }, { x: join.x2, color: next.color })
      current = next
      currentIndex = join.to
      join = outgoing.get(currentIndex)
    }
    const x2 = current.barRight - (current.ends ? current.thickness / 2 : 0)
    path += ` L ${x2} ${current.y}`
    colors.push({ x: x2, color: current.color })
    paths.push({
      path, x1, x2, thickness: first.thickness,
      stops: colors.map(stop => ({ offset: (stop.x - x1) / (x2 - x1 || 1), color: stop.color })),
      clipLeft: first.barLeft, clipRight: current.barRight,
    })
  })
  return paths
}
