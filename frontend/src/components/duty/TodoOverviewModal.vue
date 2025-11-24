<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount, nextTick } from 'vue'
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
} from 'lucide-vue-next'

interface Todo {
  id: string
  title: string
  content: string
  status: 'ACTIVE' | 'COMPLETED'
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

interface Props {
  isOpen: boolean
  todos: Todo[]
  completedTodos: Todo[]
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'showDetail', todo: Todo): void
  (e: 'complete', id: string): void
  (e: 'reopen', id: string): void
  (e: 'delete', id: string): void
  (e: 'reorder', todoIds: string[]): void
  (e: 'add'): void
}>()

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

// Check if sorting should be enabled (only active todos, no completed filter)
const isSortingEnabled = computed(() => filters.value.active && !filters.value.completed)

function initSortable() {
  if (!todoListRef.value) return

  // Destroy existing instance
  destroySortable()

  // Only init if sorting is enabled
  if (!isSortingEnabled.value) return

  sortableInstance = Sortable.create(todoListRef.value, {
    animation: 150,
    handle: '.drag-handle',
    draggable: '.todo-item-active',
    ghostClass: 'bg-blue-100',
    chosenClass: 'bg-blue-50',
    dragClass: 'opacity-50',
    onEnd: () => {
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

function formatDate(dateString: string) {
  return dateString.split('T')[0]
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-2xl max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
          <div class="flex items-center gap-3">
            <h2 class="text-base sm:text-lg font-bold">Todo List</h2>
            <span class="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
              {{ todos.length }}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <button
              @click="emit('add')"
              class="flex items-center gap-1 px-3 py-1.5 bg-green-500 text-white text-sm rounded-lg hover:bg-green-600 transition"
            >
              <Plus class="w-4 h-4" />
              <span class="hidden sm:inline">추가</span>
            </button>
            <button @click="emit('close')" class="p-2 hover:bg-gray-100 rounded-full transition">
              <X class="w-6 h-6" />
            </button>
          </div>
        </div>

        <!-- Filters -->
        <div class="px-3 sm:px-4 py-2 border-b border-gray-100 flex items-center gap-1.5 sm:gap-2 overflow-x-auto">
          <Filter class="w-4 h-4 text-gray-500 flex-shrink-0" />
          <button
            @click="toggleFilter('all')"
            class="px-2 sm:px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap"
            :class="
              filters.active && filters.completed
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            "
          >
            전체
          </button>
          <button
            @click="toggleFilter('active')"
            class="px-2 sm:px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap"
            :class="
              filters.active && !filters.completed
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            "
          >
            진행중 ({{ todos.length }})
          </button>
          <button
            @click="toggleFilter('completed')"
            class="px-2 sm:px-3 py-1 text-xs sm:text-sm rounded-full transition whitespace-nowrap"
            :class="
              !filters.active && filters.completed
                ? 'bg-gray-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            "
          >
            완료 ({{ completedTodos.length }})
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
          <div v-if="filteredTodos.length === 0" class="text-center py-12 text-gray-400">
            <Circle class="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p>표시할 할 일이 없습니다.</p>
          </div>

          <div v-else ref="todoListRef" class="space-y-3">
            <div
              v-for="todo in filteredTodos"
              :key="todo.id"
              :data-id="todo.id"
              class="border rounded-xl overflow-hidden transition-all cursor-pointer group"
              :class="{
                'bg-green-50 border-green-200': todo.status === 'COMPLETED',
                'bg-white border-gray-200 hover:border-blue-300 hover:shadow-md todo-item-active': todo.status === 'ACTIVE'
              }"
              @click="emit('showDetail', todo)"
            >
              <div class="flex items-stretch">
                <!-- Left area: drag handle or completed icon -->
                <div
                  class="flex-shrink-0 w-10 sm:w-12 flex items-center justify-center"
                  :class="{
                    'bg-green-100': todo.status === 'COMPLETED',
                    'bg-gray-50': todo.status === 'ACTIVE'
                  }"
                >
                  <!-- Completed: check icon -->
                  <CheckCircle2
                    v-if="todo.status === 'COMPLETED'"
                    class="w-6 h-6 text-green-600"
                  />
                  <!-- Active + sortable: drag handle -->
                  <div
                    v-else-if="isSortingEnabled"
                    class="drag-handle cursor-grab text-gray-400 hover:text-gray-600 p-1"
                    @click.stop
                  >
                    <GripVertical class="w-5 h-5" />
                  </div>
                  <!-- Active + not sortable: empty circle -->
                  <Circle v-else class="w-5 h-5 text-gray-300" />
                </div>

                <!-- Main content -->
                <div class="flex-1 min-w-0 p-3 sm:p-4">
                  <div class="flex items-start justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <h3
                        class="font-semibold text-sm sm:text-base truncate"
                        :class="{
                          'text-green-700 line-through': todo.status === 'COMPLETED',
                          'text-gray-800': todo.status === 'ACTIVE'
                        }"
                      >
                        {{ todo.title }}
                      </h3>
                      <div class="flex items-center gap-2 mt-1 text-xs text-gray-500">
                        <span class="flex items-center gap-1">
                          <Calendar class="w-3 h-3" />
                          {{ formatDate(todo.createdDate) }}
                        </span>
                        <span v-if="todo.completedDate" class="flex items-center gap-1 text-green-600">
                          <Check class="w-3 h-3" />
                          {{ formatDate(todo.completedDate) }}
                        </span>
                        <FileText v-if="todo.content" class="w-3.5 h-3.5 text-blue-400" title="메모 있음" />
                        <Paperclip v-if="todo.hasAttachments" class="w-3.5 h-3.5 text-purple-400" title="첨부파일 있음" />
                      </div>
                    </div>

                    <!-- Action buttons -->
                    <div class="flex items-center gap-1 flex-shrink-0" @click.stop>
                      <button
                        v-if="todo.status === 'ACTIVE'"
                        @click="emit('complete', todo.id)"
                        class="p-2 text-green-600 hover:bg-green-100 rounded-lg transition"
                        title="완료"
                      >
                        <Check class="w-5 h-5" />
                      </button>
                      <button
                        v-else
                        @click="emit('reopen', todo.id)"
                        class="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition"
                        title="재오픈"
                      >
                        <RotateCcw class="w-5 h-5" />
                      </button>
                      <button
                        @click="emit('delete', todo.id)"
                        class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-100 rounded-lg transition"
                        title="삭제"
                      >
                        <Trash2 class="w-5 h-5" />
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
