const flowingTitleClass = 'calendar-item__text--flow'

export function syncCalendarScheduleTextFlow(container: HTMLElement): void {
  const titles = [...container.querySelectorAll<HTMLElement>('.calendar-item__line--chip > .calendar-item__text')]

  // Measure every title in its two-line clamped form before switching the titles
  // that fit to inline text, so a time chip can follow their final text line.
  for (const title of titles) title.classList.remove(flowingTitleClass)
  const timedTitles = titles.filter(title => title.nextElementSibling?.classList.contains('calendar-item__time'))
  const fits = timedTitles.map(title => title.clientHeight > 0 && title.scrollHeight <= title.clientHeight + 1)
  timedTitles.forEach((title, index) => title.classList.toggle(flowingTitleClass, fits[index]))
}
