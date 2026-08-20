import { describe, expect, it } from 'vitest'
import dutyView from './DutyView.vue?raw'
import dutyHeaderControls from '@/components/duty/DutyHeaderControls.vue?raw'
import overflowMenu from '@/components/common/OverflowMenu.vue?raw'
import scheduleList from '@/components/duty/ScheduleList.vue?raw'
import todoDetailModal from '@/components/duty/TodoDetailModal.vue?raw'
import dayDetailModal from '@/components/duty/DayDetailModal.vue?raw'

describe('duty calendar report entry points', () => {
  it('shows the member menu on other members calendars only', () => {
    expect(dutyView).toContain(':show-member-menu="!isMyCalendar"')
    expect(dutyView).toContain(':show-block="isLoggedIn && !isMyCalendar"')
    expect(dutyHeaderControls).toContain("emit('report-member')")
    expect(dutyHeaderControls).toContain("emit('block-member')")
  })

  // The profile photo and the name are the menu trigger, the way a social app opens
  // member actions from the identity itself, so there is no separate overflow button.
  it('hangs the member menu off the profile photo and name', () => {
    expect(dutyHeaderControls).toMatch(
      /<OverflowMenu[\s\S]*?<template #trigger>[\s\S]*?<ProfileAvatar[\s\S]*?\{\{ memberName \}\}[\s\S]*?<\/template>[\s\S]*?emit\('report-member'\)/
    )
    expect(overflowMenu).toContain("<slot name=\"trigger\" />")
    expect(overflowMenu).not.toContain('MoreHorizontal')
  })

  it('hides the block menu item from guests', () => {
    expect(dutyHeaderControls).toMatch(/v-if="showBlock"[\s\S]*?emit\('block-member'\)/)
  })

  it('sends guests to login before opening the report form', () => {
    expect(dutyView).toContain('async function requireLogin()')
    expect(dutyView).toContain('if (isLoggedIn.value) return true')
    expect(dutyView).toContain("t('report.login.message')")
    expect(dutyView).toContain('router.push(buildLoginRoute(route.fullPath))')
    expect(dutyView).toMatch(/async function openMemberReport\(\) \{\s*if \(!await requireLogin\(\)\) return/)
    expect(dutyView).toMatch(/async function openScheduleReport\([\s\S]{0,80}?\{\s*if \(!await requireLogin\(\)\) return/)
    expect(dutyView).toMatch(/async function openTodoReport\([\s\S]{0,80}?\{\s*if \(!await requireLogin\(\)\) return/)
  })

  it('reports schedules only when someone else owns them', () => {
    expect(scheduleList).toContain('canReportCalendarSchedule(')
    expect(scheduleList).toContain('schedule.isTagged ? schedule.taggedByMember?.id ?? null : props.memberId')
    expect(scheduleList).toContain('props.viewerMemberId')
    expect(scheduleList).toMatch(/v-if="canReportSchedule\(schedule\)"[\s\S]*?emit\('report'/)
    expect(dayDetailModal).toContain("@report=\"(schedule) => emit('reportSchedule', schedule)\"")
    expect(dutyView).toContain('@report-schedule="openScheduleReport"')
    expect(dutyView).toContain(':viewer-member-id="authStore.user?.id ?? null"')
  })

  it('reports to-dos only when they were tagged onto me', () => {
    expect(dutyView).toContain(
      'const canReportSelectedTodo = computed(\n  () => isLoggedIn.value && (!isMyCalendar.value || !!selectedTodo.value?.isTagged)\n)'
    )
    expect(dutyView).toContain(':can-report="canReportSelectedTodo"')
    expect(todoDetailModal).toMatch(/v-if="canReport"[\s\S]*?emit\('report'/)
  })

  it('treats a duplicate report response as a success', () => {
    expect(dutyView).toContain("toastSuccess(t('report.messages.submitted'))")
    expect(dutyView).not.toContain('response.status === 201')
  })

  it('confirms a block, then leaves the now hidden calendar', () => {
    expect(dutyView).toMatch(
      /await confirm\(t\('report\.block\.message'\), t\('report\.block\.title'\), t\('report\.block\.confirm'\)\)/
    )
    expect(dutyView).toMatch(/await blockApi\.block\(memberId\.value\)[\s\S]*?goBack\('\/'\)/)
  })

  it('passes the alsoBlock choice straight through to the API', () => {
    expect(dutyView).toContain('alsoBlock: submission.alsoBlock')
  })

  it('refreshes my own calendar instead of leaving it when the report also blocks', () => {
    expect(dutyView).toMatch(
      /if \(submission\.alsoBlock\) \{\s*if \(isMyCalendar\.value\) \{\s*await refreshAfterBlock\(\)\s*\} else \{\s*goBack\('\/'\)\s*\}\s*\}/
    )
  })

  it('reloads the friend, tagged and overlay state the block invalidated', () => {
    expect(dutyView).toMatch(
      /async function refreshAfterBlock\(\)[\s\S]*?await loadFriends\(\)[\s\S]*?selectedFriendIds\.value = selectedFriendIds\.value\.filter[\s\S]*?loadSchedules\(\)[\s\S]*?loadTodos\(\)[\s\S]*?loadOtherDuties\(\)/
    )
  })
})

describe('schedule and to-do overflow actions', () => {
  it('hangs untag and report off one overflow trigger on a schedule row', () => {
    expect(scheduleList).toContain("import OverflowMenu from '@/components/common/OverflowMenu.vue'")
    expect(scheduleList).toContain(
      'v-if="canUntagSchedule(schedule) || canReportSchedule(schedule)"'
    )
    expect(scheduleList).toMatch(
      /<OverflowMenu[\s\S]*?v-if="canUntagSchedule\(schedule\)"[\s\S]*?emit\('request-untag'/
    )
    expect(scheduleList).toMatch(
      /<OverflowMenu[\s\S]*?v-if="canReportSchedule\(schedule\)"[\s\S]*?emit\('report'/
    )
  })

  it('keeps the visibility hint, edit and delete inline next to the trigger', () => {
    expect(scheduleList).toMatch(/<VisibilityHintIcon[\s\S]*?<OverflowMenu/)
    expect(scheduleList).toMatch(
      /<\/OverflowMenu>\s*<template v-if="canEditSchedule\(schedule\)">/
    )
  })

  it('hangs untag and report off one overflow trigger in the to-do detail footer', () => {
    expect(todoDetailModal).toContain(
      "import OverflowMenu from '@/components/common/OverflowMenu.vue'"
    )
    expect(todoDetailModal).toContain('v-if="canReport || isTaggedTodo"')
    expect(todoDetailModal).toMatch(
      /<OverflowMenu[\s\S]*?v-if="isTaggedTodo"[\s\S]*?emit\('untagSelf'/
    )
    expect(todoDetailModal).toMatch(/<OverflowMenu[\s\S]*?v-if="canReport"[\s\S]*?emit\('report'/)
    // The footer sits at the bottom of the modal, so its menu has to open upwards.
    expect(todoDetailModal).toContain('placement="above"')
    expect(todoDetailModal).toMatch(
      /<\/OverflowMenu>\s*<template v-if="!isTaggedTodo">/
    )
  })

  it('reports with a red siren wherever the calendar offers a report', () => {
    for (const source of [scheduleList, todoDetailModal, dutyHeaderControls]) {
      expect(source).not.toContain('Flag')
      expect(source).toContain('Siren')
      expect(source).toMatch(/text-dp-danger[\s\S]*?<Siren/)
    }
  })

  it('lets a row-level menu align to the right without moving the member menu', () => {
    expect(overflowMenu).toContain("align?: 'left' | 'right'")
    expect(overflowMenu).toContain("placement?: 'below' | 'above'")
    expect(overflowMenu).toContain("align: 'left'")
    expect(overflowMenu).toContain("placement: 'below'")
    expect(scheduleList).toContain('align="right"')
    expect(todoDetailModal).toContain('align="right"')
    // The member menu takes the defaults, so it stays where it was.
    expect(dutyHeaderControls).not.toContain('align="right"')
    expect(dutyHeaderControls).not.toContain('placement=')
  })
})
