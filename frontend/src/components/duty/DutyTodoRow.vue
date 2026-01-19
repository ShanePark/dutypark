<script setup lang="ts">
import { Plus, ChevronRight, ListTodo, FileText } from 'lucide-vue-next'
import type { LocalTodo } from '@/views/duty/dutyViewTypes'

type DutyTodoRowItem = Pick<LocalTodo, 'id' | 'title' | 'status' | 'content' | 'hasAttachments'>

defineProps<{
  showTodoTodo: boolean
  filteredTodos: DutyTodoRowItem[]
}>()

const emit = defineEmits<{
  (e: 'toggle-filter'): void
  (e: 'open-todo-board'): void
  (e: 'add-todo'): void
  (e: 'todo-click', todo: DutyTodoRowItem): void
}>()
</script>

<template>
  <div class="flex items-center gap-2 mb-1.5 px-1">
    <!-- Left: Todo Management Button + Add -->
    <div class="flex-shrink-0 inline-flex">
      <!-- Todo Management Button - navigates to /todo -->
      <button
        @click="emit('open-todo-board')"
        class="todo-manage-btn h-7 px-2 flex items-center gap-1 transition-all duration-150 cursor-pointer rounded-l-lg border"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)' }"
      >
        <span class="text-xs font-medium" :style="{ color: 'var(--dp-text-secondary)' }">할일</span>
        <ChevronRight class="w-3 h-3" :style="{ color: 'var(--dp-text-muted)' }" />
      </button>
      <!-- Add Todo Button -->
      <button
        @click="emit('add-todo')"
        class="todo-btn-add h-7 px-2 flex items-center justify-center transition-all duration-150 cursor-pointer rounded-r-lg border border-l-0"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-secondary)' }"
        title="새 할일 추가"
      >
        <Plus class="todo-btn-add-icon w-4 h-4 transition-transform duration-200" />
      </button>
    </div>

    <!-- Right: Todo Filter Icons + Items -->
    <div class="flex-1 min-w-0 flex items-center gap-1.5">
      <!-- TODO Filter Toggle -->
      <button
        @click="emit('toggle-filter')"
        class="todo-filter-btn flex-shrink-0 h-7 w-7 flex items-center justify-center transition-all duration-150 cursor-pointer rounded-md"
        :class="showTodoTodo ? 'todo-filter-btn-active-todo' : 'todo-filter-btn-inactive'"
        title="할일 표시"
      >
        <ListTodo class="w-4 h-4" />
      </button>
      <!-- Filtered Todo Items -->
      <div v-if="filteredTodos.length > 0" class="flex-1 min-w-0 overflow-x-auto scrollbar-hide">
        <div class="flex gap-1.5">
          <button
            v-for="todo in filteredTodos"
            :key="todo.id"
            @click="emit('todo-click', todo)"
            class="todo-item-bubble flex-shrink-0 max-w-[120px] sm:max-w-[160px] flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] sm:text-xs cursor-pointer transition-all duration-150 border"
            :style="{
              backgroundColor: todo.status === 'IN_PROGRESS' ? 'var(--dp-warning-bg)' : 'var(--dp-accent-bg)',
              borderColor: todo.status === 'IN_PROGRESS' ? 'var(--dp-warning)' : 'var(--dp-accent)',
              color: 'var(--dp-text-primary)'
            }"
          >
            <span class="truncate">{{ todo.title }}</span>
            <FileText v-if="todo.content || todo.hasAttachments" class="w-2.5 h-2.5 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
