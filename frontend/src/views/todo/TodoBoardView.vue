<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import Sortable from 'sortablejs'
import { todoApi } from '@/api/todo'
import { useSwal } from '@/composables/useSwal'
import KanbanColumn from '@/components/todo/KanbanColumn.vue'
import KanbanCard from '@/components/todo/KanbanCard.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import type { Todo, TodoBoard, TodoStatus } from '@/types'

const { showSuccess, showError, confirmDelete } = useSwal()

const board = ref<TodoBoard | null>(null)
const isLoading = ref(false)
const isAddModalOpen = ref(false)
const isDetailModalOpen = ref(false)
const selectedTodo = ref<Todo | null>(null)
const startInEditMode = ref(false)

// Sortable instances for each column
let sortableInstances: Record<string, Sortable> = {}

const todoList = computed(() => board.value?.todo ?? [])
const inProgressList = computed(() => board.value?.inProgress ?? [])
const doneList = computed(() => board.value?.done ?? [])

const counts = computed(() => board.value?.counts ?? { todo: 0, inProgress: 0, done: 0, total: 0 })

async function loadBoard() {
  isLoading.value = true
  try {
    board.value = await todoApi.getBoard()
    await nextTick()
    initSortables()
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
      await loadBoard()
    } catch (error) {
      console.error('Failed to change status:', error)
      showError('상태 변경에 실패했습니다.')
      await loadBoard()
    }
  }
}

function openAddModal() {
  isAddModalOpen.value = true
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
  dueDate?: string
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    await todoApi.createTodo({
      title: data.title,
      content: data.content,
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
  dueDate?: string | null
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    await todoApi.updateTodo(data.id, {
      title: data.title,
      content: data.content,
      dueDate: data.dueDate,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    showSuccess('할 일이 수정되었습니다.')
    closeDetailModal()
    await loadBoard()
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
  destroySortables()
})
</script>

<template>
  <div class="todo-board-container">
    <!-- Header -->
    <div class="todo-board-header">
      <h1 class="todo-board-title">할일</h1>
      <span class="todo-board-count">{{ counts.total }}</span>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading && !board" class="todo-board-loading">
      <div class="todo-board-spinner"></div>
      <p>로딩 중...</p>
    </div>

    <!-- Board -->
    <div v-else class="todo-board-content">
      <div class="todo-board-columns">
        <!-- TODO Column -->
        <KanbanColumn status="TODO" :count="counts.todo" :show-add-button="true" @add="openAddModal">
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
        <KanbanColumn status="IN_PROGRESS" :count="counts.inProgress">
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
        <KanbanColumn status="DONE" :count="counts.done">
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
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.todo-board-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--dp-text-primary);
}

@media (min-width: 640px) {
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
  scrollbar-width: none;
}

.todo-board-content::-webkit-scrollbar {
  display: none;
}

@media (min-width: 640px) {
  .todo-board-content {
    overflow: hidden;
    scroll-snap-type: none;
  }
}

.todo-board-columns {
  display: flex;
  gap: 0.75rem;
  min-height: calc(100dvh - 200px);
  padding: 0.25rem;
  box-sizing: border-box;
}

.todo-board-columns > * {
  scroll-snap-align: start;
}

@media (min-width: 640px) {
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
</style>

<style>
/* SortableJS drag-and-drop styles - must be unscoped for dynamic classes */
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
