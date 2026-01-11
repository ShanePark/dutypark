<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import Sortable from 'sortablejs'
import { HelpCircle, X, ListTodo, Clock, CheckCircle2, Lightbulb, LayoutGrid } from 'lucide-vue-next'
import { todoApi } from '@/api/todo'
import { useSwal } from '@/composables/useSwal'
import KanbanColumn from '@/components/todo/KanbanColumn.vue'
import KanbanCard from '@/components/todo/KanbanCard.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import type { Todo, TodoBoard, TodoStatus } from '@/types'

const { showSuccess, showError, confirmDelete } = useSwal()

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
let scrollRafId: number | null = null

// Sortable instances for each column
let sortableInstances: Record<string, Sortable> = {}

const todoList = computed(() => board.value?.todo ?? [])
const inProgressList = computed(() => board.value?.inProgress ?? [])
const doneList = computed(() => board.value?.done ?? [])

const counts = computed(() => board.value?.counts ?? { todo: 0, inProgress: 0, done: 0, total: 0 })
const statusTabs: Array<{ status: TodoStatus; label: string; icon: typeof ListTodo }> = [
  { status: 'TODO', label: '할일', icon: ListTodo },
  { status: 'IN_PROGRESS', label: '진행중', icon: Clock },
  { status: 'DONE', label: '완료', icon: CheckCircle2 },
]

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
    showError('보드를 불러오는데 실패했습니다.')
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
      onEnd: handleDragEnd,
    })
  })
}

function destroySortables() {
  Object.values(sortableInstances).forEach((instance) => {
    if (instance) {
      instance.destroy()
    }
  })
  sortableInstances = {}
}

async function handleDragEnd(evt: Sortable.SortableEvent) {
  const todoId = evt.item.getAttribute('data-id')
  if (!todoId) return

  const fromColumn = evt.from.getAttribute('data-column') as TodoStatus
  const toColumn = evt.to.getAttribute('data-column') as TodoStatus

  if (fromColumn === toColumn) {
    // Within-column reordering
    const columnItems = evt.to.querySelectorAll('[data-id]')
    const orderedIds: string[] = []
    columnItems.forEach((item) => {
      const id = item.getAttribute('data-id')
      if (id) orderedIds.push(id)
    })

    try {
      await todoApi.updatePositions({
        status: toColumn,
        orderedIds,
      })
      await loadBoard()
    } catch (error) {
      console.error('Failed to update positions:', error)
      showError('순서 변경에 실패했습니다.')
      await loadBoard()
    }
  } else {
    // Cross-column move (status change)
    const newPosition = evt.newIndex ?? 0

    try {
      await todoApi.changeStatus(todoId, {
        status: toColumn,
        position: newPosition,
      })
      focusStatus(toColumn, 'smooth')
      await loadBoard()
    } catch (error) {
      console.error('Failed to change status:', error)
      showError('상태 변경에 실패했습니다.')
      await loadBoard()
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
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    await todoApi.createTodo({
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    showSuccess('할 일이 추가되었습니다.')
    isAddModalOpen.value = false
    await loadBoard()
  } catch (error) {
    console.error('Failed to create todo:', error)
    showError('할 일 추가에 실패했습니다.')
  }
}

async function handleUpdateTodo(data: {
  id: string
  title: string
  content: string
  status: TodoStatus
  dueDate?: string | null
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    await todoApi.updateTodo(data.id, {
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    showSuccess('할 일이 수정되었습니다.')
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
    showError('할 일 수정에 실패했습니다.')
  }
}

async function handleCompleteTodo(id: string) {
  try {
    await todoApi.completeTodo(id)
    showSuccess('할 일을 완료했습니다.')
    closeDetailModal()
    await loadBoard()
  } catch (error) {
    console.error('Failed to complete todo:', error)
    showError('완료 처리에 실패했습니다.')
  }
}

async function handleReopenTodo(id: string) {
  try {
    await todoApi.reopenTodo(id)
    showSuccess('할 일을 재오픈했습니다.')
    closeDetailModal()
    await loadBoard()
  } catch (error) {
    console.error('Failed to reopen todo:', error)
    showError('재오픈에 실패했습니다.')
  }
}

async function handleDeleteTodo(id: string) {
  const confirmed = await confirmDelete('정말 삭제하시겠습니까?')
  if (!confirmed) return

  try {
    await todoApi.deleteTodo(id)
    showSuccess('할 일이 삭제되었습니다.')
    closeDetailModal()
    await loadBoard()
  } catch (error) {
    console.error('Failed to delete todo:', error)
    showError('삭제에 실패했습니다.')
  }
}

function handleBackToList() {
  closeDetailModal()
}

onMounted(() => {
  loadBoard()
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
    <!-- Header -->
    <div class="todo-board-header">
      <div class="todo-board-header-left">
        <h1 class="todo-board-title">할일</h1>
        <span class="todo-board-count">{{ counts.total }}</span>
      </div>
      <button
        class="todo-board-help-btn"
        @click="isHelpModalOpen = true"
        aria-label="도움말"
      >
        <HelpCircle />
      </button>
    </div>

    <div class="todo-board-tabs" role="tablist" aria-label="할일 상태">
      <button
        v-for="tab in statusTabs"
        :key="tab.status"
        type="button"
        class="todo-board-tab"
        :class="{ active: activeStatus === tab.status }"
        @click="focusStatus(tab.status)"
        :aria-pressed="activeStatus === tab.status"
      >
        <component :is="tab.icon" class="todo-board-tab-icon" />
        <span class="todo-board-tab-label">{{ tab.label }}</span>
        <span class="todo-board-tab-count">{{ getStatusCount(tab.status) }}</span>
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading && !board" class="todo-board-loading">
      <div class="todo-board-spinner"></div>
      <p>로딩 중...</p>
    </div>

    <!-- Board -->
    <div
      v-else
      ref="boardScroller"
      class="todo-board-content"
      @scroll.passive="handleBoardScroll"
    >
      <div class="todo-board-columns">
        <!-- TODO Column -->
        <KanbanColumn status="TODO" :count="counts.todo" @add="openAddModal('TODO')">
          <div data-column="TODO" class="kanban-column-drop-zone">
            <div
              v-for="todo in todoList"
              :key="todo.id"
              :data-id="todo.id"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <div v-if="todoList.length === 0" class="kanban-empty-state">
              할 일이 없습니다
            </div>
          </div>
        </KanbanColumn>

        <!-- IN_PROGRESS Column -->
        <KanbanColumn status="IN_PROGRESS" :count="counts.inProgress" @add="openAddModal('IN_PROGRESS')">
          <div data-column="IN_PROGRESS" class="kanban-column-drop-zone">
            <div
              v-for="todo in inProgressList"
              :key="todo.id"
              :data-id="todo.id"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <div v-if="inProgressList.length === 0" class="kanban-empty-state">
              진행 중인 일이 없습니다
            </div>
          </div>
        </KanbanColumn>

        <!-- DONE Column -->
        <KanbanColumn status="DONE" :count="counts.done" @add="openAddModal('DONE')">
          <div data-column="DONE" class="kanban-column-drop-zone">
            <div
              v-for="todo in doneList"
              :key="todo.id"
              :data-id="todo.id"
              class="kanban-card-wrapper"
            >
              <KanbanCard :todo="todo" @click="openDetailModal(todo)" />
            </div>
            <div v-if="doneList.length === 0" class="kanban-empty-state">
              완료된 일이 없습니다
            </div>
          </div>
        </KanbanColumn>
      </div>
    </div>

    <!-- Modals -->
    <TodoAddModal
      :is-open="isAddModalOpen"
      :initial-status="addModalInitialStatus"
      @close="isAddModalOpen = false"
      @save="handleAddTodo"
    />

    <TodoDetailModal
      :is-open="isDetailModalOpen"
      :todo="selectedTodo"
      :start-in-edit-mode="startInEditMode"
      @close="closeDetailModal"
      @update="handleUpdateTodo"
      @complete="handleCompleteTodo"
      @reopen="handleReopenTodo"
      @delete="handleDeleteTodo"
      @back-to-list="handleBackToList"
    />

    <!-- Help Modal -->
    <Teleport to="body">
      <Transition name="modal">
        <div
          v-if="isHelpModalOpen"
          class="help-modal-overlay"
          @click.self="isHelpModalOpen = false"
        >
          <div class="help-modal">
            <div class="help-modal-header">
              <h2 class="help-modal-title">할일 보드 사용법</h2>
              <button
                class="help-modal-close"
                @click="isHelpModalOpen = false"
                aria-label="닫기"
              >
                <X />
              </button>
            </div>
            <div class="help-modal-content">
              <section class="help-section">
                <h3 class="help-section-title">
                  <LayoutGrid class="help-section-icon" />
                  칸반 보드란?
                </h3>
                <p class="help-section-text">
                  할일을 <strong>할일</strong>, <strong>진행중</strong>, <strong>완료</strong> 세 단계로 나누어 관리하는 방식입니다.
                  카드를 드래그하여 상태를 쉽게 변경할 수 있습니다.
                </p>
              </section>

              <section class="help-section">
                <h3 class="help-section-title">
                  <ListTodo class="help-section-icon" />
                  할일 (TODO)
                </h3>
                <p class="help-section-text">
                  아직 시작하지 않은 할일들이 여기에 표시됩니다.
                  <strong>+</strong> 버튼을 눌러 새로운 할일을 추가하세요.
                </p>
              </section>

              <section class="help-section">
                <h3 class="help-section-title">
                  <Clock class="help-section-icon" />
                  진행중 (IN PROGRESS)
                </h3>
                <p class="help-section-text">
                  현재 작업 중인 할일들입니다.
                  <strong class="help-highlight">진행중 상태의 할일은 내 달력에 표시</strong>되어
                  오늘 집중해야 할 일을 한눈에 확인할 수 있습니다.
                </p>
              </section>

              <section class="help-section">
                <h3 class="help-section-title">
                  <CheckCircle2 class="help-section-icon" />
                  완료 (DONE)
                </h3>
                <p class="help-section-text">
                  완료된 할일들이 여기에 보관됩니다.
                  필요하면 다시 진행중이나 할일로 되돌릴 수 있습니다.
                </p>
              </section>

              <section class="help-section">
                <h3 class="help-section-title">
                  <Lightbulb class="help-section-icon" />
                  사용 팁
                </h3>
                <ul class="help-tips-list">
                  <li>카드를 <strong>드래그&드롭</strong>하여 상태를 변경하세요</li>
                  <li>같은 컬럼 내에서도 드래그로 <strong>순서를 조정</strong>할 수 있습니다</li>
                  <li>카드를 클릭하면 <strong>상세 내용</strong>을 확인하고 수정할 수 있습니다</li>
                  <li><strong>마감일</strong>을 설정하면 기한 관리가 편리합니다</li>
                  <li>필요한 경우 <strong>파일을 첨부</strong>할 수도 있습니다</li>
                </ul>
              </section>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.todo-board-container {
  min-height: 100dvh;
  padding: 0.5rem;
  padding-bottom: calc(80px + env(safe-area-inset-bottom));
  background-color: var(--dp-bg-secondary);
  max-width: 896px;
  margin: 0 auto;
  overflow-x: hidden;
}

@media (min-width: 640px) {
  .todo-board-container {
    padding: 1rem;
    padding-bottom: calc(100px + env(safe-area-inset-bottom));
  }
}

.todo-board-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.todo-board-header-left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.todo-board-help-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 50%;
  border: none;
  background-color: transparent;
  color: var(--dp-text-muted);
  cursor: pointer;
  transition: all 0.15s ease;
}

.todo-board-help-btn:hover {
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-secondary);
}

.todo-board-help-btn svg {
  width: 1.25rem;
  height: 1.25rem;
}

.todo-board-tabs {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.5rem;
  margin-bottom: 0.75rem;
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
  border-color: var(--dp-accent);
  color: var(--dp-accent);
  box-shadow: 0 4px 10px rgba(59, 130, 246, 0.15);
}

.todo-board-tab-icon {
  width: 0.95rem;
  height: 0.95rem;
}

.todo-board-tab-label {
  text-align: left;
}

.todo-board-tab-count {
  font-size: 0.7rem;
  padding: 0.1rem 0.4rem;
  border-radius: 999px;
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-muted);
}

.todo-board-tab.active .todo-board-tab-count {
  background-color: var(--dp-accent-bg);
  color: var(--dp-accent);
}

.todo-board-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--dp-text-primary);
}

@media (min-width: 640px) {
  .todo-board-tabs {
    display: none;
  }

  .todo-board-title {
    font-size: 1.75rem;
  }
}

.todo-board-count {
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  background-color: var(--dp-accent);
  color: white;
}

.todo-board-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 4rem 0;
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
  overflow-x: auto;
  padding-bottom: 1rem;
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
    overflow: hidden;
    scroll-snap-type: none;
    scroll-padding: 0;
  }
}

.todo-board-columns {
  display: flex;
  gap: 0.65rem;
  min-height: calc(100dvh - 200px);
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
  align-items: center;
  justify-content: center;
  padding: 2rem 1rem;
  color: var(--dp-text-muted);
  font-size: 0.875rem;
  text-align: center;
  border: 2px dashed var(--dp-border-secondary);
  border-radius: 0.5rem;
  min-height: 80px;
}

/* Help Modal Styles */
.help-modal-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  z-index: 1000;
}

.help-modal {
  background-color: var(--dp-bg-card);
  border-radius: 1rem;
  max-width: 500px;
  width: 100%;
  max-height: 85vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: var(--dp-shadow-lg);
}

.help-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--dp-border-primary);
  flex-shrink: 0;
}

.help-modal-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--dp-text-primary);
}

.help-modal-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  border: none;
  background-color: transparent;
  color: var(--dp-text-muted);
  cursor: pointer;
  transition: all 0.15s ease;
}

.help-modal-close:hover {
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-secondary);
}

.help-modal-close svg {
  width: 1.25rem;
  height: 1.25rem;
}

.help-modal-content {
  padding: 1.25rem;
  overflow-y: auto;
  flex: 1;
}

.help-section {
  margin-bottom: 1.25rem;
}

.help-section:last-child {
  margin-bottom: 0;
}

.help-section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--dp-text-primary);
  margin-bottom: 0.5rem;
}

.help-section-icon {
  width: 1.125rem;
  height: 1.125rem;
  flex-shrink: 0;
  color: var(--dp-text-secondary);
}

.help-section-text {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
  line-height: 1.6;
}

.help-section-text strong {
  color: var(--dp-text-primary);
  font-weight: 600;
}

.help-highlight {
  background-color: var(--dp-warning-bg);
  color: var(--dp-warning);
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
}

.help-tips-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.help-tips-list li {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
  line-height: 1.5;
  padding-left: 1.25rem;
  position: relative;
}

.help-tips-list li::before {
  content: '•';
  position: absolute;
  left: 0;
  color: var(--dp-accent);
  font-weight: bold;
}

.help-tips-list li strong {
  color: var(--dp-text-primary);
  font-weight: 600;
}

/* Modal Transition */
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-active .help-modal,
.modal-leave-active .help-modal {
  transition: transform 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from .help-modal,
.modal-leave-to .help-modal {
  transform: scale(0.95);
}
</style>

<style>
/* SortableJS drag-and-drop styles - must be unscoped for dynamic classes */

/* Hide empty state when dragging item enters the column */
.kanban-column-drop-zone:has(.kanban-ghost) .kanban-empty-state {
  display: none;
}

.kanban-ghost {
  opacity: 0.5;
  background-color: var(--dp-accent-bg) !important;
  border: 2px dashed var(--dp-accent) !important;
  border-radius: 0.5rem;
}

.kanban-chosen {
  box-shadow: 0 0 0 2px var(--dp-accent), var(--dp-shadow-lg) !important;
  border-radius: 0.5rem;
}

.kanban-drag {
  opacity: 1 !important;
}

.kanban-fallback {
  opacity: 0.95 !important;
  box-shadow: var(--dp-shadow-lg) !important;
  transform: rotate(2deg) !important;
  background-color: var(--dp-bg-card) !important;
  border-radius: 0.5rem;
}
</style>
