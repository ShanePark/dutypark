export interface DescriptionChange { before: string; after: string }

/** Compare Unicode characters and group edits separated by unchanged text. */
export function descriptionChanges(before: string, after: string): DescriptionChange[] {
  const previous = Array.from(before)
  const next = Array.from(after)
  if (before === after) return []
  const nextCharacters = new Set(next)
  if (!previous.some(character => nextCharacters.has(character))) return [{ before, after }]
  const trace: Map<number, number>[] = []
  let frontier = new Map<number, number>([[1, 0]])
  // Bound trace memory for long rewrites while keeping small edits precise.
  const maximumDistance = Math.min(previous.length + next.length, 256)
  for (let distance = 0; distance <= maximumDistance; distance++) {
    const current = new Map<number, number>()
    for (let diagonal = -distance; diagonal <= distance; diagonal += 2) {
      const down = diagonal === -distance || (diagonal !== distance
        && (frontier.get(diagonal - 1) ?? -1) < (frontier.get(diagonal + 1) ?? -1))
      let x = down ? frontier.get(diagonal + 1) ?? 0 : (frontier.get(diagonal - 1) ?? 0) + 1
      let y = x - diagonal
      while (x < previous.length && y < next.length && previous[x] === next[y]) { x++; y++ }
      current.set(diagonal, x)
      if (x >= previous.length && y >= next.length) {
        trace.push(current)
        return collectChanges(previous, next, trace)
      }
    }
    trace.push(current)
    frontier = current
  }
  let start = 0
  while (start < previous.length && start < next.length && previous[start] === next[start]) start++
  let end = 0
  while (end < previous.length - start && end < next.length - start
    && previous[previous.length - end - 1] === next[next.length - end - 1]) end++
  return [{ before: previous.slice(start, previous.length - end).join(''), after: next.slice(start, next.length - end).join('') }]
}

function collectChanges(previous: string[], next: string[], trace: Map<number, number>[]): DescriptionChange[] {
  let x = previous.length
  let y = next.length
  const matches: Array<[number, number]> = []
  for (let distance = trace.length - 1; distance >= 0; distance--) {
    const frontier = trace[distance - 1] ?? new Map<number, number>([[1, 0]])
    const diagonal = x - y
    const down = diagonal === -distance || (diagonal !== distance
      && (frontier.get(diagonal - 1) ?? -1) < (frontier.get(diagonal + 1) ?? -1))
    const previousDiagonal = down ? diagonal + 1 : diagonal - 1
    const previousX = frontier.get(previousDiagonal) ?? 0
    const previousY = previousX - previousDiagonal
    while (x > previousX && y > previousY) { matches.push([--x, --y]) }
    x = previousX
    y = previousY
  }
  matches.reverse()
  // A shared space inside otherwise replaced words is not useful context to omit.
  const meaningfulMatches: Array<[number, number]> = []
  for (let start = 0; start < matches.length;) {
    let end = start + 1
    while (end < matches.length && matches[end]![0] === matches[end - 1]![0] + 1
      && matches[end]![1] === matches[end - 1]![1] + 1) end++
    const run = matches.slice(start, end)
    const isBoundary = run[0]![0] === 0 && run[0]![1] === 0
      || run[run.length - 1]![0] === previous.length - 1 && run[run.length - 1]![1] === next.length - 1
    if (isBoundary || run.some(([index]) => previous[index]!.trim())) meaningfulMatches.push(...run)
    start = end
  }
  const changes: DescriptionChange[] = []
  let previousStart = 0
  let nextStart = 0
  for (const [previousMatch, nextMatch] of [...meaningfulMatches, [previous.length, next.length] as [number, number]]) {
    if (previousMatch > previousStart || nextMatch > nextStart) {
      changes.push({ before: previous.slice(previousStart, previousMatch).join(''), after: next.slice(nextStart, nextMatch).join('') })
    }
    previousStart = previousMatch + 1
    nextStart = nextMatch + 1
  }
  return changes
}
