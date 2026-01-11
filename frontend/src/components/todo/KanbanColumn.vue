<script setup lang="ts">
import { Plus, ListTodo, Clock, CheckCircle2 } from 'lucide-vue-next'
import type { TodoStatus } from '@/types'
import type { Component } from 'vue'

interface Props {
  status: TodoStatus
  count: number
}

defineProps<Props>()

const emit = defineEmits<{
  (e: 'add'): void
}>()

const statusConfig: Record<TodoStatus, { label: string; bgClass: string; textClass: string; icon: Component }> = {
  TODO: {
    label: '할일',
    bgClass: 'kanban-column-todo',
    textClass: 'kanban-title-todo',
    icon: ListTodo,
  },
  IN_PROGRESS: {
    label: '진행중',
    bgClass: 'kanban-column-in-progress',
    textClass: 'kanban-title-in-progress',
    icon: Clock,
  },
  DONE: {
    label: '완료',
    bgClass: 'kanban-column-done',
    textClass: 'kanban-title-done',
    icon: CheckCircle2,
  },
}
</script>

<template>
  <div class="kanban-column" :class="statusConfig[status].bgClass">
    <div class="kanban-column-header">
      <h3 class="kanban-column-title" :class="statusConfig[status].textClass">
        <component :is="statusConfig[status].icon" class="kanban-column-icon" />
        {{ statusConfig[status].label }}
      </h3>
      <div class="kanban-column-header-right">
        <span class="kanban-column-count" :class="statusConfig[status].textClass">{{ count }}</span>
        <button
          class="kanban-column-add-btn"
          @click="emit('add')"
          title="새 할일 추가"
        >
          <Plus class="w-4 h-4" />
        </button>
      </div>
    </div>
    <div class="kanban-column-content">
      <slot></slot>
    </div>
  </div>
</template>

<style scoped>
.kanban-column {
  display: flex;
  flex-direction: column;
  min-width: 62vw;
  max-width: 62vw;
  flex-shrink: 0;
  border-radius: 0.75rem;
  padding: 0.75rem;
  height: 100%;
}

/* First column snaps to start (no left padding) */
.kanban-column:first-child {
  scroll-snap-align: start;
}

/* Last column snaps to end */
.kanban-column:last-child {
  scroll-snap-align: end;
}

@media (min-width: 640px) {
  .kanban-column {
    min-width: 0;
    max-width: 100%;
    flex: 1 1 0;
    overflow: hidden;
  }
}

.kanban-column-todo {
  background-color: var(--dp-bg-tertiary);
}

.kanban-column-in-progress {
  background-color: color-mix(in srgb, var(--dp-warning) 15%, var(--dp-bg-tertiary));
}

.kanban-column-done {
  background-color: color-mix(in srgb, var(--dp-success) 15%, var(--dp-bg-tertiary));
}

.kanban-column-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.5rem;
  background-color: var(--dp-bg-card);
}

.kanban-column-header-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.kanban-column-title {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.875rem;
  font-weight: 700;
}

.kanban-column-icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.kanban-title-todo {
  color: var(--dp-text-primary);
}

.kanban-title-in-progress {
  color: var(--dp-warning);
}

.kanban-title-done {
  color: var(--dp-success);
}

.kanban-column-count {
  font-size: 0.75rem;
  font-weight: 600;
  min-width: 1.5rem;
  text-align: center;
}

.kanban-column-add-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 0.375rem;
  background-color: var(--dp-accent);
  color: white;
  cursor: pointer;
  transition: all 0.15s ease;
  border: none;
}

.kanban-column-add-btn:hover {
  background-color: var(--dp-accent-hover);
  transform: scale(1.1);
}

.kanban-column-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  min-height: 100px;
  overflow-y: auto;
  padding-top: 0.125rem;
}

/* Scrollbar styling for column content */
.kanban-column-content::-webkit-scrollbar {
  width: 4px;
}

.kanban-column-content::-webkit-scrollbar-track {
  background: transparent;
}

.kanban-column-content::-webkit-scrollbar-thumb {
  background-color: var(--dp-border-secondary);
  border-radius: 2px;
}
</style>
