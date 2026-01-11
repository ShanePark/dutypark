<script setup lang="ts">
import { computed } from 'vue'
import { Paperclip, Calendar } from 'lucide-vue-next'
import type { Todo } from '@/types'

interface Props {
  todo: Todo
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'click', todo: Todo): void
}>()

const formattedDueDate = computed(() => {
  if (!props.todo.dueDate) return null
  const date = new Date(props.todo.dueDate)
  const month = date.getMonth() + 1
  const day = date.getDate()
  return `${month}/${day}`
})
</script>

<template>
  <div
    class="kanban-card"
    @click="emit('click', todo)"
  >
    <div class="kanban-card-header">
      <h4 class="kanban-card-title">{{ todo.title }}</h4>
      <Paperclip
        v-if="todo.hasAttachments"
        class="kanban-card-attachment-icon"
      />
    </div>
    <p
      v-if="todo.content"
      class="kanban-card-content"
    >
      {{ todo.content }}
    </p>
    <div
      v-if="formattedDueDate"
      class="kanban-card-due-date"
      :class="{ 'kanban-card-due-date--overdue': todo.isOverdue }"
    >
      <Calendar class="kanban-card-due-date-icon" />
      <span>{{ formattedDueDate }}</span>
    </div>
  </div>
</template>

<style scoped>
.kanban-card {
  padding: 0.75rem;
  border-radius: 0.5rem;
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-primary);
  cursor: pointer;
  transition: all 0.15s ease;
  user-select: none;
}

.kanban-card:hover {
  border-color: var(--dp-accent-border);
  background-color: var(--dp-accent-bg);
  transform: translateY(-1px);
  box-shadow: var(--dp-shadow-sm);
}

.kanban-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.5rem;
}

.kanban-card-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--dp-text-primary);
  line-height: 1.4;
  word-break: break-word;
  flex: 1;
  min-width: 0;
}

.kanban-card-attachment-icon {
  flex-shrink: 0;
  width: 1rem;
  height: 1rem;
  color: var(--dp-text-muted);
}

.kanban-card-content {
  margin-top: 0.375rem;
  font-size: 0.75rem;
  color: var(--dp-text-secondary);
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  word-break: break-word;
}

.kanban-card-due-date {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin-top: 0.5rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  background-color: var(--dp-bg-tertiary);
  font-size: 0.75rem;
  color: var(--dp-text-secondary);
  width: fit-content;
}

.kanban-card-due-date--overdue {
  background-color: var(--dp-danger-bg);
  color: var(--dp-danger);
}

.kanban-card-due-date-icon {
  width: 0.75rem;
  height: 0.75rem;
  flex-shrink: 0;
}
</style>
