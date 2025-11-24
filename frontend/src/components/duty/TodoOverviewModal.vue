<script setup lang="ts">
import { ref, computed } from 'vue'
import {
  X,
  GripVertical,
  Check,
  RotateCcw,
  Trash2,
  FileText,
  Filter,
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
}>()

const filters = ref({
  active: true,
  completed: false,
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

function toggleFilter(type: 'active' | 'completed' | 'all') {
  if (type === 'all') {
    filters.value.active = true
    filters.value.completed = true
  } else {
    filters.value[type] = !filters.value[type]
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
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <div class="flex items-center gap-3">
            <h2 class="text-lg font-bold">Todo List</h2>
            <span class="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
              {{ todos.length }}
            </span>
          </div>
          <button @click="emit('close')" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Filters -->
        <div class="px-4 py-2 border-b border-gray-100 flex items-center gap-2">
          <Filter class="w-4 h-4 text-gray-500" />
          <button
            @click="toggleFilter('all')"
            class="px-3 py-1 text-sm rounded-full transition"
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
            class="px-3 py-1 text-sm rounded-full transition"
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
            class="px-3 py-1 text-sm rounded-full transition"
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
        <div class="p-4 overflow-y-auto max-h-[calc(90vh-180px)]">
          <div v-if="filteredTodos.length === 0" class="text-center py-8 text-gray-400">
            표시할 할 일이 없습니다.
          </div>

          <div v-else class="space-y-2">
            <div
              v-for="todo in filteredTodos"
              :key="todo.id"
              class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition group"
              :class="{ 'opacity-60': todo.status === 'COMPLETED' }"
            >
              <!-- Drag Handle (only for active todos) -->
              <div
                v-if="todo.status === 'ACTIVE'"
                class="cursor-grab text-gray-400 hover:text-gray-600"
              >
                <GripVertical class="w-5 h-5" />
              </div>
              <div v-else class="w-5"></div>

              <!-- Content -->
              <div
                class="flex-1 min-w-0 cursor-pointer"
                @click="emit('showDetail', todo)"
              >
                <div class="flex items-center gap-2">
                  <span
                    class="font-medium"
                    :class="{ 'line-through text-gray-400': todo.status === 'COMPLETED' }"
                  >
                    {{ todo.title }}
                  </span>
                  <FileText
                    v-if="todo.content || todo.hasAttachments"
                    class="w-4 h-4 text-gray-400"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-0.5">
                  {{ formatDate(todo.createdDate) }}
                  <span v-if="todo.completedDate">
                    - {{ formatDate(todo.completedDate) }}
                  </span>
                </p>
              </div>

              <!-- Actions -->
              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition">
                <button
                  v-if="todo.status === 'ACTIVE'"
                  @click.stop="emit('complete', todo.id)"
                  class="p-1.5 text-green-600 hover:bg-green-100 rounded transition"
                  title="완료"
                >
                  <Check class="w-4 h-4" />
                </button>
                <button
                  v-else
                  @click.stop="emit('reopen', todo.id)"
                  class="p-1.5 text-blue-600 hover:bg-blue-100 rounded transition"
                  title="재오픈"
                >
                  <RotateCcw class="w-4 h-4" />
                </button>
                <button
                  @click.stop="emit('delete', todo.id)"
                  class="p-1.5 text-red-600 hover:bg-red-100 rounded transition"
                  title="삭제"
                >
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
