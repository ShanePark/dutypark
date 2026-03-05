<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount, nextTick, toRef } from 'vue'
import Sortable from 'sortablejs'
import type { SortableEvent } from 'sortablejs'
import {
  X,
  GripVertical,
  Check,
  RotateCcw,
  Trash2,
  FileText,
  Filter,
  CheckCircle2,
  Circle,
  Paperclip,
  Calendar,
  Plus,
  Pencil,
} from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { extractDatePart } from '@/utils/date'

interface Todo {
  id: string
  title: string
  content: string
  status: 'TODO' | 'IN_PROGRESS' | 'DONE'
  createdDate: string
  completedDate?: string
  hasAttachments: boolean
  attachments: Array<{
    id: string
    name: string
    originalFilename: string
    size: number
    contentType: string
    isImage: boolean
    hasThumbnail: boolean
    thumbnailUrl?: string
    downloadUrl: string
  }>
}

// Helper functions for status compatibility
function isActive(status: string): boolean {
  return status === 'TODO' || status === 'IN_PROGRESS'
}

function isDone(status: string): boolean {
  return status === 'DONE'
}

interface Props {
  isOpen: boolean
  todos: Todo[]
  completedTodos: Todo[]
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'showDetail', todo: Todo): void
  (e: 'edit', todo: Todo): void
  (e: 'complete', id: string): void
  (e: 'reopen', id: string): void
  (e: 'delete', id: string): void
  (e: 'reorder', todoIds: string[]): void
  (e: 'add'): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const filters = ref({
  active: true,
  completed: true,
})

const filteredTodos = computed(() => {
  const items: Todo[] = []
  if (filters.value.active) {
    items.push(...props.todos)
  }
  if (filters.value.completed) {
    items.push(...props.completedTodos)
  }
  return items
})

// SortableJS integration
const todoListRef = ref<HTMLElement | null>(null)
let sortableInstance: Sortable | null = null
let isDragging = false

// Check if sorting should be enabled (when active todos are shown)
const isSortingEnabled = computed(() => filters.value.active)

function initSortable() {
  if (!todoListRef.value) return

  // Destroy existing instance
  destroySortable()

  // Only init if sorting is enabled
  if (!isSortingEnabled.value) return

  sortableInstance = Sortable.create(todoListRef.value, {
    animation: 200,
    handle: '.drag-handle',
    draggable: '.todo-item-active',
    ghostClass: 'sortable-ghost',
    chosenClass: 'sortable-chosen',
    dragClass: 'sortable-drag',
    forceFallback: true,
    fallbackClass: 'sortable-fallback',
    onStart: () => {
      isDragging = true
    },
    onEnd: () => {
      // Delay resetting isDragging to prevent click event from firing
      setTimeout(() => {
        isDragging = false
      }, 100)

      // Read new order directly from DOM elements
      if (!todoListRef.value) return
      const todoElements = todoListRef.value.querySelectorAll('[data-id]')
      const newOrderIds: string[] = []
      todoElements.forEach((el) => {
        const id = el.getAttribute('data-id')
        // Only include active todos (not completed)
        const todo = props.todos.find(t => t.id === id)
        if (id && todo) {
          newOrderIds.push(id)
        }
      })

      if (newOrderIds.length > 0) {
        emit('reorder', newOrderIds)
      }
    },
  })
}

function destroySortable() {
  if (sortableInstance) {
    sortableInstance.destroy()
    sortableInstance = null
  }
}

// Initialize sortable when modal opens
watch(
  () => props.isOpen,
  async (isOpen) => {
    if (isOpen) {
      // Wait for DOM to render
      await nextTick()
      // Additional delay to ensure DOM is fully ready
      setTimeout(() => {
        if (isSortingEnabled.value) {
          initSortable()
        }
      }, 100)
    } else {
      destroySortable()
    }
  }
)

// Reinitialize when filter or todos change
watch(
  [isSortingEnabled, () => props.todos],
  async () => {
    if (props.isOpen) {
      await nextTick()
      if (isSortingEnabled.value) {
        initSortable()
      } else {
        destroySortable()
      }
    }
  }
)

// Cleanup on unmount
onBeforeUnmount(() => {
  destroySortable()
})

function toggleFilter(type: 'active' | 'completed' | 'all') {
  if (type === 'all') {
    filters.value.active = true
    filters.value.completed = true
  } else if (type === 'active') {
    filters.value.active = true
    filters.value.completed = false
  } else {
    filters.value.active = false
    filters.value.completed = true
  }
}


function handleTodoClick(todo: Todo) {
  // Ignore click if we just finished dragging
  if (isDragging) return
  emit('showDetail', todo)
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-dp-overlay-dark/50"
      @click.self="emit('close')"
    >
      <div class="modal-container modal-container-rounded max-w-[95vw] sm:max-w-xl max-h-[90dvh] sm:max-h-[85vh]">
        <!-- Header -->
        <div class="flex items-center justify-between px-4 py-3 sm:px-5 sm:py-4 bg-dp-bg-tertiary border-b border-dp-border-primary">
          <div class="flex items-center gap-2">
            <h2 class="text-base sm:text-lg font-bold text-dp-text-primary">Todo</h2>
            <span class="bg-dp-accent text-dp-text-on-dark text-xs px-2 py-0.5 rounded-full">
              {{ todos.length }}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <button
              @click="emit('add')"
              class="flex items-center gap-1 px-3 py-1.5 bg-dp-success text-dp-text-on-dark text-sm rounded-lg hover:bg-dp-success-hover transition cursor-pointer"
            >
              <Plus class="w-4 h-4" />
              <span class="hidden sm:inline">추가</span>
            </button>
            <button @click="emit('close')" class="p-1.5 rounded-lg transition hover:bg-dp-overlay-dark/10 cursor-pointer text-dp-text-muted">
              <X class="w-5 h-5" />
            </button>
          </div>
        </div>

        <!-- Filters -->
        <div class="px-4 sm:px-5 py-2.5 flex items-center gap-2 overflow-x-auto bg-dp-bg-card border-b border-dp-border-primary">
          <Filter class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
          <button
            @click="toggleFilter('all')"
            class="px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap cursor-pointer"
            :class="
              filters.active && filters.completed
                ? 'bg-dp-surface-strong text-dp-text-on-dark'
                : 'hover:bg-dp-overlay-dark/5'
            "
            :style="!(filters.active && filters.completed) ? { color: 'var(--dp-text-secondary)' } : {}"
          >
            전체
          </button>
          <button
            @click="toggleFilter('active')"
            class="px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap cursor-pointer"
            :class="
              filters.active && !filters.completed
                ? 'bg-dp-accent text-dp-text-on-dark'
                : 'hover:bg-dp-overlay-dark/5'
            "
            :style="!(filters.active && !filters.completed) ? { color: 'var(--dp-text-secondary)' } : {}"
          >
            진행중 ({{ todos.length }})
          </button>
          <button
            @click="toggleFilter('completed')"
            class="px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap cursor-pointer"
            :class="
              !filters.active && filters.completed
                ? 'bg-dp-success text-dp-text-on-dark'
                : 'hover:bg-dp-overlay-dark/5'
            "
            :style="!(!filters.active && filters.completed) ? { color: 'var(--dp-text-secondary)' } : {}"
          >
            완료 ({{ completedTodos.length }})
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)] bg-dp-bg-secondary">
          <div v-if="filteredTodos.length === 0" class="text-center py-12 text-dp-text-muted">
            <Circle class="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p>표시할 할 일이 없습니다.</p>
          </div>

          <div v-else ref="todoListRef" class="space-y-2">
            <div
              v-for="todo in filteredTodos"
              :key="todo.id"
              :data-id="todo.id"
              class="rounded-lg overflow-hidden transition-all cursor-pointer group border"
              :class="{
                'todo-item-completed opacity-60 border-dp-success-border': isDone(todo.status),
                'hover:shadow-md hover:border-dp-accent-border todo-item-active': isActive(todo.status)
              }"
              :style="{
                backgroundColor: 'var(--dp-bg-card)',
                borderColor: isActive(todo.status) ? 'var(--dp-border-primary)' : undefined
              }"
              @click="handleTodoClick(todo)"
            >
              <div class="flex items-stretch">
                <!-- Left area: drag handle or completed icon -->
                <div
                  class="flex-shrink-0 w-9 sm:w-10 flex items-center justify-center"
                  :class="{
                    'bg-dp-success/10': isDone(todo.status)
                  }"
                  :style="{
                    backgroundColor: isActive(todo.status) ? 'var(--dp-bg-tertiary)' : undefined
                  }"
                >
                  <!-- Completed: check icon -->
                  <CheckCircle2
                    v-if="isDone(todo.status)"
                    class="w-5 h-5 text-dp-success"
                  />
                  <!-- Active + sortable: drag handle -->
                  <div
                    v-else-if="isSortingEnabled"
                    class="drag-handle cursor-grab active:cursor-grabbing hover:text-dp-accent rounded p-1 transition-colors text-dp-text-muted"
                    @click.stop
                    title="드래그하여 순서 변경"
                  >
                    <GripVertical class="w-4 h-4" />
                  </div>
                  <!-- Active + not sortable: empty circle -->
                  <Circle v-else class="w-4 h-4 text-dp-text-muted" />
                </div>

                <!-- Main content -->
                <div class="flex-1 min-w-0 py-2.5 px-3 sm:py-3 sm:px-4">
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <h3
                        class="font-medium text-sm sm:text-base truncate"
                        :class="{
                          'text-dp-success line-through': isDone(todo.status)
                        }"
                        :style="{
                          color: isActive(todo.status) ? 'var(--dp-text-primary)' : undefined
                        }"
                      >
                        {{ todo.title }}
                      </h3>
                      <div class="flex items-center gap-2 mt-0.5 text-xs text-dp-text-muted">
                        <span class="flex items-center gap-1">
                          <Calendar class="w-3 h-3" />
                          {{ extractDatePart(todo.createdDate) }}
                        </span>
                        <span v-if="todo.completedDate" class="flex items-center gap-1 text-dp-success">
                          <Check class="w-3 h-3" />
                          {{ extractDatePart(todo.completedDate) }}
                        </span>
                        <FileText v-if="todo.content" class="w-3.5 h-3.5 text-dp-accent-light" title="메모 있음" />
                        <Paperclip v-if="todo.hasAttachments" class="w-3.5 h-3.5 text-dp-accent-light" title="첨부파일 있음" />
                      </div>
                    </div>

                    <!-- Action buttons -->
                    <div class="flex items-center gap-0.5 flex-shrink-0" @click.stop>
                      <button
                        v-if="isActive(todo.status)"
                        @click="emit('complete', todo.id)"
                        class="p-1.5 text-dp-success hover:bg-dp-success/10 rounded-md transition cursor-pointer"
                        title="완료"
                      >
                        <Check class="w-4 h-4 sm:w-5 sm:h-5" />
                      </button>
                      <button
                        v-else
                        @click="emit('reopen', todo.id)"
                        class="p-1.5 text-dp-accent hover:bg-dp-accent/10 rounded-md transition cursor-pointer"
                        title="재오픈"
                      >
                        <RotateCcw class="w-4 h-4 sm:w-5 sm:h-5" />
                      </button>
                      <button
                        @click="emit('edit', todo)"
                        class="p-1.5 text-dp-accent hover:bg-dp-accent/10 rounded-md transition cursor-pointer"
                        title="수정"
                      >
                        <Pencil class="w-4 h-4 sm:w-5 sm:h-5" />
                      </button>
                      <button
                        @click="emit('delete', todo.id)"
                        class="p-1.5 text-dp-danger hover:bg-dp-danger/10 rounded-md transition cursor-pointer"
                        title="삭제"
                      >
                        <Trash2 class="w-4 h-4 sm:w-5 sm:h-5" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style>
/* SortableJS drag-and-drop styles - must be unscoped for dynamic classes */
.sortable-ghost {
  background-color: var(--dp-accent-bg) !important;
  border-color: var(--dp-accent-border) !important;
  opacity: 0.6 !important;
}

.sortable-chosen {
  box-shadow: 0 0 0 2px var(--dp-accent-light), var(--dp-shadow-lg) !important;
}

.sortable-drag {
  opacity: 1 !important;
}

.sortable-fallback {
  opacity: 0.9 !important;
  box-shadow: var(--dp-shadow-lg) !important;
  transform: rotate(1deg) !important;
}
</style>
