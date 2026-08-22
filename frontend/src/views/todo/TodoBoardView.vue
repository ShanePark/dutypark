<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
import Sortable from 'sortablejs'
import type { MoveEvent, SortableEvent } from 'sortablejs'
import { ListTodo, Clock, CheckCircle2, Lightbulb, LayoutGrid, Plus } from 'lucide-vue-next'
import { todoApi } from '@/api/todo'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { useContentFilterStore } from '@/stores/contentFilter'
import { useDragClickGuard } from '@/composables/useDragClickGuard'
import HelpButton from '@/components/common/HelpButton.vue'
import HelpModal from '@/components/common/HelpModal.vue'
import HelpNote from '@/components/common/HelpNote.vue'
import HelpSection from '@/components/common/HelpSection.vue'
import PageHeader from '@/components/common/PageHeader.vue'
import KanbanColumn from '@/components/todo/KanbanColumn.vue'
import KanbanCard from '@/components/todo/KanbanCard.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import type { TaggableFriend, Todo, TodoBoard, TodoStatus } from '@/types'

const { t } = useI18n()
const { showSuccess, showError, confirm, confirmDelete, toastSuccess } = useSwal()
const contentFilterStore = useContentFilterStore()
const dragClickGuard = useDragClickGuard()

const isHelpModalOpen = ref(false)

const board = ref<TodoBoard | null>(null)
const boardScroller = ref<HTMLElement | null>(null)
const isLoading = ref(false)
const isAddModalOpen = ref(false)
const addModalInitialStatus = ref<TodoStatus>('TODO')
const isDetailModalOpen = ref(false)
const selectedTodo = ref<Todo | null>(null)
const startInEditMode = ref(false)
const activeStatus = ref<TodoStatus>('IN_PROGRESS')
const friends = ref<TaggableFriend[]>([])
let scrollRafId: number | null = null
let dragFocusRafId: number | null = null
let activeDragStatus: TodoStatus | null = null
let dragStartStatus: TodoStatus | null = null
let dragEdgeStatus: TodoStatus | null = null
let dragFocusTargetStatus: TodoStatus | null = null
let dragUsesTouchInput = false

let sortableInstances: Record<string, Sortable> = {}

const todoList = computed(() => board.value?.todo ?? [])
const inProgressList = computed(() => board.value?.inProgress ?? [])
const doneList = computed(() => board.value?.done ?? [])

const counts = computed(() => board.value?.counts ?? { todo: 0, inProgress: 0, done: 0, total: 0 })
const statusTabs = computed<Array<{ status: TodoStatus; label: string; icon: typeof ListTodo }>>(() => [
  { status: 'TODO', label: t('todoBoard.statusShort.todo'), icon: ListTodo },
  { status: 'IN_PROGRESS', label: t('todoBoard.statusShort.inProgress'), icon: Clock },
  { status: 'DONE', label: t('todoBoard.statusShort.done'), icon: CheckCircle2 },
])

function getStatusCount(status: TodoStatus): number {
  switch (status) {
    case 'TODO':
      return counts.value.todo
    case 'IN_PROGRESS':
      return counts.value.inProgress
    case 'DONE':
      return counts.value.done
    default:
      return 0
  }
}

async function loadBoard() {
  isLoading.value = true
  try {
    board.value = await todoApi.getBoard()
    await nextTick()
    initSortables()
    if (counts.value.total > 0 && getStatusCount(activeStatus.value) === 0) {
      activeStatus.value = getDefaultStatus()
    }
    // Use setTimeout to ensure DOM is fully rendered before scrolling on mobile
    setTimeout(() => {
      focusStatus(activeStatus.value, 'instant')
    }, 50)
  } catch (error) {
    console.error('Failed to load board:', error)
    showError(t('todoBoard.messages.loadFailed'))
  } finally {
    isLoading.value = false
  }
}

function initSortables() {
  destroySortables()

  const columns: { ref: string; status: TodoStatus }[] = [
    { ref: 'todo-column', status: 'TODO' },
    { ref: 'in-progress-column', status: 'IN_PROGRESS' },
    { ref: 'done-column', status: 'DONE' },
  ]

  columns.forEach(({ ref: refName, status }) => {
    const el = document.querySelector(`[data-column="${status}"]`) as HTMLElement
    if (!el) return

    sortableInstances[refName] = Sortable.create(el, {
      group: 'kanban',
      animation: 200,
      draggable: '.kanban-card-wrapper',
      ghostClass: 'kanban-ghost',
      chosenClass: 'kanban-chosen',
      dragClass: 'kanban-drag',
      forceFallback: true,
      fallbackClass: 'kanban-fallback',
      fallbackOnBody: true,
      delay: 150,
      delayOnTouchOnly: true,
      touchStartThreshold: 4,
      scroll: true,
      scrollSensitivity: 80,
      scrollSpeed: 10,
      swapThreshold: 0.65,
      onStart: () => {
        activeDragStatus = null
        dragEdgeStatus = null
        dragStartStatus = activeStatus.value
        dragUsesTouchInput = false
        document.addEventListener('pointermove', handleDragPointerMove, { capture: true })
        document.addEventListener('touchmove', handleDragPointerMove, { capture: true, passive: false })
        dragClickGuard.startDrag()
      },
      onMove: handleDragMove,
      onEnd: (event) => {
        const previousActiveStatus = dragStartStatus
        removeDragPointerListeners()
        activeDragStatus = null
        dragEdgeStatus = null
        dragStartStatus = null
        dragUsesTouchInput = false
        dragClickGuard.endDrag()
        void handleDragEnd(event, previousActiveStatus)
      },
    })
  })
}

function handleDragMove(event: MoveEvent) {
  const toColumn = event.to.getAttribute('data-column') as TodoStatus | null
  if (!toColumn || toColumn === activeDragStatus) return

  // After edge navigation starts, Sortable can keep reporting the source list until
  // the moving viewport places the destination beneath the finger. Do not let that
  // stale report undo the status the user just navigated to.
  if (
    toColumn === dragStartStatus
    && activeDragStatus !== null
    && activeDragStatus !== dragStartStatus
  ) return

  activeDragStatus = toColumn
  // Sortable keeps the fallback drag's Y-axis placement/reordering. We only move the
  // board horizontally when the destination changes, so following a mobile column does
  // not interfere with the user's vertical finger movement inside that column.
  activeStatus.value = toColumn
  focusDraggedStatus(toColumn)
}

function handleDragPointerMove(event: PointerEvent | TouchEvent) {
  const touch = 'touches' in event ? event.touches[0] : undefined
  const clientX = touch?.clientX ?? (event as PointerEvent).clientX
  const isTouchInput = 'touches' in event || (event as PointerEvent).pointerType === 'touch'
  if (isTouchInput) dragUsesTouchInput = true
  const container = boardScroller.value
  if (!container || !Number.isFinite(clientX)) return
  if (container.scrollWidth <= container.clientWidth) return

  const rect = container.getBoundingClientRect()
  const insideViewport = clientX >= rect.left && clientX <= rect.right
  if (!insideViewport) {
    dragEdgeStatus = null
    return
  }

  const atLeadingEdge = clientX <= rect.left + 56
  const atTrailingEdge = clientX >= rect.right - 56
  if (!atLeadingEdge && !atTrailingEdge) {
    dragEdgeStatus = null
    return
  }
  if (isTouchInput && event.cancelable) event.preventDefault()
  if (dragEdgeStatus !== null) {
    focusDraggedStatus(dragEdgeStatus)
    return
  }

  const statuses: TodoStatus[] = ['TODO', 'IN_PROGRESS', 'DONE']
  const currentIndex = statuses.indexOf(activeStatus.value)
  if (currentIndex < 0) return

  const direction = atLeadingEdge ? -1 : 1
  const nextStatus = statuses[currentIndex + direction]
  if (!nextStatus) return

  dragEdgeStatus = nextStatus
  activeDragStatus = nextStatus
  focusDraggedStatus(nextStatus)
}

function focusDraggedStatus(status: TodoStatus) {
  activeStatus.value = status
  dragFocusTargetStatus = status

  // Mobile browsers may defer animation frames until the active touch gesture ends.
  // Apply the actual board position in this touchmove so the column changes while
  // the card is still held. Mouse dragging keeps the eased animation below.
  if (dragUsesTouchInput) {
    if (dragFocusRafId !== null) {
      window.cancelAnimationFrame(dragFocusRafId)
      dragFocusRafId = null
    }
    const container = boardScroller.value
    const target = container
      ?.querySelector(`[data-column="${status}"]`)
      ?.closest('.kanban-column') as HTMLElement | null
    if (!container || !target) {
      dragFocusTargetStatus = null
      return
    }

    const desiredLeft = target.offsetLeft - (container.clientWidth - target.clientWidth) / 2
    const maxLeft = Math.max(0, container.scrollWidth - container.clientWidth)
    const left = Math.min(Math.max(desiredLeft, 0), maxLeft)
    container.scrollLeft = left
    dragFocusTargetStatus = null
    return
  }

  if (dragFocusRafId !== null) return

  // A programmatic smooth scroll issued inside a mobile touchmove can be discarded
  // when the browser finishes handling that same gesture. Drive the real scroll
  // position from the next frame instead, and keep it pinned while the edge is held.
  const moveBoardToDraggedStatus = () => {
    dragFocusRafId = null
    const targetStatus = dragFocusTargetStatus
    const container = boardScroller.value
    if (!targetStatus || !container) {
      dragFocusTargetStatus = null
      return
    }

    const target = container
      .querySelector(`[data-column="${targetStatus}"]`)
      ?.closest('.kanban-column') as HTMLElement | null
    if (!target) {
      dragFocusTargetStatus = null
      return
    }

    const desiredLeft = target.offsetLeft - (container.clientWidth - target.clientWidth) / 2
    const maxLeft = Math.max(0, container.scrollWidth - container.clientWidth)
    const left = Math.min(Math.max(desiredLeft, 0), maxLeft)
    const distance = left - container.scrollLeft
    if (Math.abs(distance) <= 1) {
      container.scrollLeft = left
    } else {
      container.scrollLeft += distance * 0.42
    }

    const shouldKeepMoving = Math.abs(left - container.scrollLeft) > 1
      || dragEdgeStatus === targetStatus
    if (shouldKeepMoving) {
      dragFocusRafId = window.requestAnimationFrame(moveBoardToDraggedStatus)
    } else {
      dragFocusTargetStatus = null
    }
  }

  dragFocusRafId = window.requestAnimationFrame(moveBoardToDraggedStatus)
}

function cancelDragStatusFocus() {
  if (dragFocusRafId !== null) {
    window.cancelAnimationFrame(dragFocusRafId)
    dragFocusRafId = null
  }
  dragFocusTargetStatus = null
}

function removeDragPointerListeners() {
  document.removeEventListener('pointermove', handleDragPointerMove, { capture: true })
  document.removeEventListener('touchmove', handleDragPointerMove, { capture: true })
}

function collectOrderedIds(container: Element | null): string[] {
  if (!(container instanceof HTMLElement)) {
    return []
  }
  // Tagged and own cards share one ordering space per column, so persist every card.
  const orderedIds: string[] = []
  container.querySelectorAll('[data-id]').forEach((item) => {
    const id = item.getAttribute('data-id')
    if (id) orderedIds.push(id)
  })
  return orderedIds
}

function destroySortables() {
  cancelDragStatusFocus()
  removeDragPointerListeners()
  dragUsesTouchInput = false
  Object.values(sortableInstances).forEach((instance) => {
    if (instance) {
      instance.destroy()
    }
  })
  sortableInstances = {}
  if (dragClickGuard.isDragging.value) {
    dragClickGuard.cancelDrag()
  }
}

async function handleDragEnd(evt: SortableEvent, previousActiveStatus: TodoStatus | null = null) {
  const todoId = evt.item.getAttribute('data-id')
  if (!todoId) return

  const fromColumn = evt.from.getAttribute('data-column') as TodoStatus
  const toColumn = evt.to.getAttribute('data-column') as TodoStatus
  const statusToRestore = previousActiveStatus ?? fromColumn

  // Full order of the destination column after SortableJS moved the card.
  const orderedIds = collectOrderedIds(evt.to)

  if (fromColumn === toColumn) {
    try {
      await todoApi.updatePositions({
        status: toColumn,
        orderedIds,
      })
      await loadBoard()
    } catch (error) {
      console.error('Failed to update positions:', error)
      showError(t('todoBoard.messages.reorderFailed'))
      await loadBoard()
    }
  } else {
    // Cross-column move (status change) — persist the destination column order too.
    try {
      await todoApi.changeStatus(todoId, {
        status: toColumn,
        orderedIds,
      })
      focusStatus(toColumn, 'smooth')
      await loadBoard()
    } catch (error) {
      console.error('Failed to change status:', error)
      showError(t('todoBoard.messages.changeStatusFailed'))
      await loadBoard()
      // A failed save must return the board to the status that was visible before
      // the live drag-follow moved the viewport to its destination.
      activeStatus.value = statusToRestore
      focusStatus(statusToRestore, 'smooth')
    }
  }
}

function openAddModal(status: TodoStatus = 'TODO') {
  addModalInitialStatus.value = status
  isAddModalOpen.value = true
}

function getDefaultStatus(): TodoStatus {
  if (board.value?.inProgress?.length) return 'IN_PROGRESS'
  if (board.value?.todo?.length) return 'TODO'
  return 'DONE'
}

function focusStatus(status: TodoStatus, behavior: ScrollBehavior = 'smooth') {
  cancelDragStatusFocus()
  activeStatus.value = status
  const container = boardScroller.value
  if (!container) return
  if (container.scrollWidth <= container.clientWidth) return
  const target = container.querySelector(`[data-column="${status}"]`)?.closest('.kanban-column') as HTMLElement | null
  if (!target) return
  // Use scrollTo instead of scrollIntoView to prevent unwanted Y-axis scrolling on mobile
  const left = target.offsetLeft - (container.clientWidth - target.clientWidth) / 2
  container.scrollTo({ left, behavior })
}

function handleBoardScroll() {
  if (!boardScroller.value) return
  if (boardScroller.value.scrollWidth <= boardScroller.value.clientWidth) return
  if (scrollRafId !== null) return
  scrollRafId = window.requestAnimationFrame(() => {
    scrollRafId = null
    syncActiveStatusWithScroll()
  })
}

function syncActiveStatusWithScroll() {
  const container = boardScroller.value
  if (!container) return
  if (dragClickGuard.isDragging.value && activeDragStatus) return
  if (dragFocusTargetStatus) return
  const columns = Array.from(container.querySelectorAll('.kanban-column')) as HTMLElement[]
  if (columns.length === 0) return
  const containerRect = container.getBoundingClientRect()
  const centerX = containerRect.left + container.clientWidth / 2
  let closest: { status: TodoStatus; distance: number } | null = null

  for (const column of columns) {
    const dropZone = column.querySelector('[data-column]') as HTMLElement | null
    const status = dropZone?.getAttribute('data-column') as TodoStatus | null
    if (!status) continue
    const rect = column.getBoundingClientRect()
    const columnCenter = rect.left + rect.width / 2
    const distance = Math.abs(centerX - columnCenter)
    if (!closest || distance < closest.distance) {
      closest = { status, distance }
    }
  }

  if (closest && closest.status !== activeStatus.value) {
    activeStatus.value = closest.status
  }
}

function openDetailModal(todo: Todo, editMode = false) {
  selectedTodo.value = todo
  startInEditMode.value = editMode
  isDetailModalOpen.value = true
}

function closeDetailModal() {
  isDetailModalOpen.value = false
  selectedTodo.value = null
  startInEditMode.value = false
}

async function handleAddTodo(data: {
  title: string
  content: string
  status: TodoStatus
  dueDate?: string
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  if (contentFilterStore.isBlocked(data.title, data.content)) {
    showError(t('contentFilter.blocked'))
    return
  }

  try {
    await todoApi.createTodo({
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    toastSuccess(t('todoBoard.messages.createSuccess'))
    isAddModalOpen.value = false
    await loadBoard()
  } catch (error) {
    console.error('Failed to create todo:', error)
    showError(t('todoBoard.messages.createFailed'))
  }
}

async function handleUpdateTodo(data: {
  id: string
  title: string
  content: string
  status: TodoStatus
  dueDate?: string | null
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  if (contentFilterStore.isBlocked(data.title, data.content)) {
    showError(t('contentFilter.blocked'))
    return
  }

  try {
    await todoApi.updateTodo(data.id, {
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    await loadBoard()
    // Update selectedTodo with fresh data from the board so modal shows updated content
    if (selectedTodo.value && board.value) {
      const allTodos = [...board.value.todo, ...board.value.inProgress, ...board.value.done]
      const updatedTodo = allTodos.find(t => t.id === data.id)
      if (updatedTodo) {
        selectedTodo.value = updatedTodo
      }
    }
  } catch (error) {
    console.error('Failed to update todo:', error)
    showError(t('todoBoard.messages.updateFailed'))
  }
}

async function handleDeleteTodo(todo: Pick<Todo, 'id' | 'title'>) {
  const confirmed = await confirmDelete(t('todoBoard.messages.deleteConfirm', { title: todo.title }))
  if (!confirmed) return

  try {
    await todoApi.deleteTodo(todo.id)
    toastSuccess(t('todoBoard.messages.deleteSuccess'))
    closeDetailModal()
    await loadBoard()
  } catch (error) {
    console.error('Failed to delete todo:', error)
    showError(t('todoBoard.messages.deleteFailed'))
  }
}

async function handleUntagSelf(todo: Pick<Todo, 'id' | 'title'>) {
  const confirmed = await confirm(
    t('todoBoard.messages.untagConfirm', { title: todo.title }),
    t('todoBoard.messages.untagTitle'),
  )
  if (!confirmed) return

  try {
    await todoApi.untagSelf(todo.id)
    showSuccess(t('todoBoard.messages.untagSuccess'))
    closeDetailModal()
    await loadBoard()
  } catch (error) {
    console.error('Failed to untag self:', error)
    showError(t('todoBoard.messages.untagFailed'))
  }
}

async function loadFriends() {
  try {
    const response = await friendApi.getFriends()
    friends.value = response.data
  } catch (error) {
    console.error('Failed to load friends:', error)
  }
}

function handleBackToList() {
  closeDetailModal()
}

onMounted(() => {
  loadBoard()
  loadFriends()
})

onBeforeUnmount(() => {
  if (scrollRafId !== null) {
    window.cancelAnimationFrame(scrollRafId)
    scrollRafId = null
  }
  destroySortables()
})
</script>

<template>
  <div class="todo-board-container">
    <PageHeader :title="t('header.menu.todo')" :icon="ListTodo" class="shrink-0">
      <HelpButton
        :label="t('todoBoard.help.openAriaLabel')"
        @click="isHelpModalOpen = true"
      />
    </PageHeader>

    <div class="todo-board-tabs" role="tablist" :aria-label="t('todoBoard.statusTabsAriaLabel')">
      <button
        v-for="tab in statusTabs"
        :key="tab.status"
        type="button"
        class="todo-board-tab"
        :class="[
          `todo-board-tab-${tab.status.toLowerCase().replace('_', '-')}`,
          { active: activeStatus === tab.status }
        ]"
        @click="focusStatus(tab.status)"
        :aria-pressed="activeStatus === tab.status"
      >
        <component :is="tab.icon" class="todo-board-tab-icon" />
        <span class="todo-board-tab-label">{{ tab.label }}</span>
        <span class="todo-board-tab-count">{{ getStatusCount(tab.status) }}</span>
      </button>
    </div>

    <div v-if="isLoading && !board" class="todo-board-loading">
      <div class="todo-board-spinner"></div>
      <p>{{ t('todoBoard.loading') }}</p>
    </div>

    <div
      v-else
      ref="boardScroller"
      class="todo-board-content"
      @scroll.passive="handleBoardScroll"
      @pointerdown.capture="dragClickGuard.handlePointerDown"
      @click.capture="dragClickGuard.handleClick"
    >
      <div class="todo-board-columns">
        <KanbanColumn
          status="TODO"
          :count="counts.todo"
          clickable-header
          @select="focusStatus"
          @add="openAddModal('TODO')"
        >
          <div data-column="TODO" class="kanban-column-drop-zone">
            <div
              v-for="todo in todoList"
              :key="todo.id"
              :data-id="todo.id"
              :data-is-tagged="todo.isTagged"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <button
              v-if="todoList.length === 0"
              class="kanban-empty-state kanban-empty-state-clickable"
              @click="openAddModal('TODO')"
            >
              <Plus class="kanban-empty-icon" />
              <span>{{ t('todoBoard.actions.clickToAdd') }}</span>
            </button>
          </div>
        </KanbanColumn>

        <KanbanColumn
          status="IN_PROGRESS"
          :count="counts.inProgress"
          clickable-header
          @select="focusStatus"
          @add="openAddModal('IN_PROGRESS')"
        >
          <div data-column="IN_PROGRESS" class="kanban-column-drop-zone">
            <div
              v-for="todo in inProgressList"
              :key="todo.id"
              :data-id="todo.id"
              :data-is-tagged="todo.isTagged"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <button
              v-if="inProgressList.length === 0"
              class="kanban-empty-state kanban-empty-state-clickable"
              @click="openAddModal('IN_PROGRESS')"
            >
              <Plus class="kanban-empty-icon" />
              <span>{{ t('todoBoard.actions.clickToAdd') }}</span>
            </button>
          </div>
        </KanbanColumn>

        <KanbanColumn
          status="DONE"
          :count="counts.done"
          clickable-header
          @select="focusStatus"
          @add="openAddModal('DONE')"
        >
          <div data-column="DONE" class="kanban-column-drop-zone">
            <div
              v-for="todo in doneList"
              :key="todo.id"
              :data-id="todo.id"
              :data-is-tagged="todo.isTagged"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <button
              v-if="doneList.length === 0"
              class="kanban-empty-state kanban-empty-state-clickable"
              @click="openAddModal('DONE')"
            >
              <Plus class="kanban-empty-icon" />
              <span>{{ t('todoBoard.actions.clickToAdd') }}</span>
            </button>
          </div>
        </KanbanColumn>
      </div>
    </div>

    <TodoAddModal
      :is-open="isAddModalOpen"
      :initial-status="addModalInitialStatus"
      :friends="friends"
      @close="isAddModalOpen = false"
      @save="handleAddTodo"
    />

    <TodoDetailModal
      :is-open="isDetailModalOpen"
      :todo="selectedTodo"
      :friends="friends"
      :start-in-edit-mode="startInEditMode"
      :show-back-to-list="false"
      @close="closeDetailModal"
      @update="handleUpdateTodo"
      @delete="handleDeleteTodo"
      @untag-self="handleUntagSelf"
      @back-to-list="handleBackToList"
    />

    <HelpModal
      :is-open="isHelpModalOpen"
      :title="t('todoBoard.help.title')"
      @close="isHelpModalOpen = false"
    >
      <!-- The blocks describe the board and its three columns rather than steps to
           follow in order, so they stay unnumbered. -->
      <HelpSection
        :icon="LayoutGrid"
        :title="t('todoBoard.help.whatIsKanbanTitle')"
        :text="t('todoBoard.help.whatIsKanbanText')"
      />
      <HelpSection
        :icon="ListTodo"
        :title="t('todoBoard.help.todoTitle')"
        :text="t('todoBoard.help.todoText')"
      />
      <HelpSection
        :icon="Clock"
        :title="t('todoBoard.help.inProgressTitle')"
        :text="t('todoBoard.help.inProgressText')"
      />
      <HelpSection
        :icon="CheckCircle2"
        :title="t('todoBoard.help.doneTitle')"
        :text="t('todoBoard.help.doneText')"
      />

      <HelpNote
        :icon="Lightbulb"
        tone="warning"
        :title="t('todoBoard.help.tipsTitle')"
        :messages="[
          t('todoBoard.help.tips.drag'),
          t('todoBoard.help.tips.reorder'),
          t('todoBoard.help.tips.details'),
          t('todoBoard.help.tips.dueDate'),
          t('todoBoard.help.tips.attachments'),
        ]"
      />
    </HelpModal>
  </div>
</template>

<style scoped>
.todo-board-container {
  /* Height calculation: 100dvh - header(48px) - footer(56px + safe-area) - extra buffer */
  height: calc(100dvh - 3rem - 72px - env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  padding: 0.5rem;
  padding-bottom: 0;
  background-color: var(--dp-bg-secondary);
  max-width: 896px;
  margin: 0 auto;
  overflow: hidden;
}

@media (min-width: 640px) {
  .todo-board-container {
    /* Desktop: header(56px) + footer(64px + safe-area) + extra buffer */
    height: calc(100dvh - 3.5rem - 100px - env(safe-area-inset-bottom));
    padding: 1rem;
    padding-bottom: 0;
  }
}

.todo-board-tabs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  flex-shrink: 0;
}

.todo-board-tab {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 0.35rem;
  padding: 0.55rem 0.6rem;
  border-radius: 0.75rem;
  border: 1px solid var(--dp-border-primary);
  background-color: var(--dp-bg-card);
  color: var(--dp-text-secondary);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  min-height: 44px;
}

.todo-board-tab:hover {
  background-color: var(--dp-bg-hover);
  transform: translateY(-1px);
}

.todo-board-tab.active {
  border-width: 2px;
  background-color: var(--dp-bg-card);
  box-shadow: var(--dp-shadow-sm);
}

.todo-board-tab-todo {
  color: var(--dp-accent);
}

.todo-board-tab-todo.active {
  border-color: var(--dp-accent);
}

.todo-board-tab-in-progress {
  color: var(--dp-warning);
}

.todo-board-tab-in-progress.active {
  border-color: var(--dp-warning);
}

.todo-board-tab-done {
  color: var(--dp-success);
}

.todo-board-tab-done.active {
  border-color: var(--dp-success);
}

.todo-board-tab-icon {
  width: 0.95rem;
  height: 0.95rem;
}

.todo-board-tab-label {
  text-align: left;
  white-space: nowrap;
}

.todo-board-tab-count {
  font-size: 0.7rem;
  padding: 0.1rem 0.4rem;
  border-radius: 999px;
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-muted);
}

.todo-board-tab-todo.active .todo-board-tab-count {
  background-color: var(--dp-accent);
  color: var(--dp-text-on-dark);
}

.todo-board-tab-in-progress.active .todo-board-tab-count {
  background-color: var(--dp-warning);
  color: var(--dp-text-on-dark);
}

.todo-board-tab-done.active .todo-board-tab-count {
  background-color: var(--dp-success);
  color: var(--dp-text-on-dark);
}

@media (min-width: 640px) {
  .todo-board-tabs {
    display: none;
  }
}

.todo-board-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  flex: 1;
  color: var(--dp-text-muted);
}

.todo-board-spinner {
  width: 2rem;
  height: 2rem;
  border: 3px solid var(--dp-border-secondary);
  border-top-color: var(--dp-accent);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.todo-board-content {
  flex: 1;
  min-height: 0;
  overflow-x: auto;
  overflow-y: hidden;
  -webkit-overflow-scrolling: touch;
  scroll-snap-type: x mandatory;
  scroll-padding-inline-start: 0.5rem;
  scroll-padding-inline-end: 0.5rem;
  scrollbar-width: none;
}

.todo-board-content::-webkit-scrollbar {
  display: none;
}

@media (min-width: 640px) {
  .todo-board-content {
    overflow-x: hidden;
    scroll-snap-type: none;
    scroll-padding: 0;
  }
}

.todo-board-columns {
  display: flex;
  gap: 0.65rem;
  height: 100%;
  padding: 0.25rem 0.5rem;
  padding-right: calc(100vw - 62vw - 0.5rem);
  box-sizing: border-box;
}

.todo-board-columns > * {
  scroll-snap-align: center;
}

@media (min-width: 640px) {
  .todo-board-columns {
    gap: 0.75rem;
    padding: 0.25rem;
  }

  .todo-board-columns > * {
    scroll-snap-align: none;
  }
}

@media (min-width: 768px) {
  .todo-board-columns {
    gap: 1rem;
  }
}

@media (min-width: 1024px) {
  .todo-board-columns {
    gap: 1.25rem;
  }
}

.kanban-column-drop-zone {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  min-height: 100px;
  flex: 1;
}

.kanban-card-wrapper {
  touch-action: none;
}

.kanban-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2rem 1rem;
  color: var(--dp-text-muted);
  font-size: 0.875rem;
  text-align: center;
  border: 2px dashed var(--dp-border-secondary);
  border-radius: 0.5rem;
  min-height: 80px;
  width: 100%;
  background: transparent;
}

.kanban-empty-state-clickable {
  cursor: pointer;
  transition: all 0.15s ease;
}

.kanban-empty-state-clickable:hover {
  border-color: var(--dp-accent);
  color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
}

.kanban-empty-icon {
  width: 1.5rem;
  height: 1.5rem;
  opacity: 0.7;
}

.kanban-empty-state-clickable:hover .kanban-empty-icon {
  opacity: 1;
}

</style>

<style>
/* SortableJS drag-and-drop styles - must be unscoped for dynamic classes */

.kanban-column-drop-zone:has(.kanban-ghost) .kanban-empty-state {
  display: none;
}

.kanban-ghost {
  opacity: 0.5;
  background-color: var(--dp-accent-bg) !important;
  border: 2px dashed var(--dp-accent) !important;
  border-radius: 0.875rem;
}

.kanban-chosen {
  box-shadow: 0 0 0 2px var(--dp-accent), var(--dp-shadow-lg) !important;
  border-radius: 0.875rem;
}

.kanban-drag {
  opacity: 1 !important;
}

.kanban-fallback {
  opacity: 0 !important;
  pointer-events: none !important;
}
</style>
