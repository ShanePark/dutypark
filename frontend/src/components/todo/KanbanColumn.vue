<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Plus, ListTodo, Clock, CheckCircle2 } from 'lucide-vue-next'
import type { TodoStatus } from '@/types'
import type { Component } from 'vue'

interface Props {
  status: TodoStatus
  count: number
  clickableHeader?: boolean
}

withDefaults(defineProps<Props>(), {
  clickableHeader: false,
})

const emit = defineEmits<{
  (e: 'add'): void
  (e: 'select', status: TodoStatus): void
}>()
const { t } = useI18n()

const statusConfig: Record<TodoStatus, { labelKey: string; shortLabelKey: string; bgClass: string; textClass: string; icon: Component }> = {
  TODO: {
    labelKey: 'todoBoard.status.todo',
    shortLabelKey: 'todoBoard.statusShort.todo',
    bgClass: 'kanban-column-todo',
    textClass: 'kanban-title-todo',
    icon: ListTodo,
  },
  IN_PROGRESS: {
    labelKey: 'todoBoard.status.inProgress',
    shortLabelKey: 'todoBoard.statusShort.inProgress',
    bgClass: 'kanban-column-in-progress',
    textClass: 'kanban-title-in-progress',
    icon: Clock,
  },
  DONE: {
    labelKey: 'todoBoard.status.done',
    shortLabelKey: 'todoBoard.statusShort.done',
    bgClass: 'kanban-column-done',
    textClass: 'kanban-title-done',
    icon: CheckCircle2,
  },
}
</script>

<template>
  <div class="kanban-column" :class="statusConfig[status].bgClass">
    <div class="kanban-column-header">
      <div
        class="kanban-column-header-main"
        :class="{ 'kanban-column-header-main-clickable': clickableHeader }"
        :role="clickableHeader ? 'button' : undefined"
        :tabindex="clickableHeader ? 0 : -1"
        @click="clickableHeader && emit('select', status)"
        @keydown.enter.prevent="clickableHeader && emit('select', status)"
        @keydown.space.prevent="clickableHeader && emit('select', status)"
      >
        <h3 class="kanban-column-title" :class="statusConfig[status].textClass">
          <component :is="statusConfig[status].icon" class="kanban-column-icon" />
          <span class="sm:hidden">{{ t(statusConfig[status].shortLabelKey) }}</span>
          <span class="hidden sm:inline">{{ t(statusConfig[status].labelKey) }}</span>
        </h3>
        <span class="kanban-column-count" :class="statusConfig[status].textClass">{{ count }}</span>
      </div>
      <button
        type="button"
        class="kanban-column-add-btn"
        @click="emit('add')"
        :title="t('todoBoard.actions.addNew')"
      >
        <Plus class="w-4 h-4" />
      </button>
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
  min-height: 0;
  overflow: hidden;
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
  }
}

.kanban-column-todo {
  background-color: color-mix(in srgb, var(--dp-accent) 12%, var(--dp-bg-tertiary));
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
  gap: 0.5rem;
  margin-bottom: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.5rem;
  background-color: var(--dp-bg-card);
  flex-shrink: 0;
  transition: background-color 0.15s ease, box-shadow 0.15s ease;
}

/* Hovering the clickable title region tints the WHOLE header bar edge-to-edge
   with the column's accent color (plus a thin accent ring), instead of drawing
   a smaller nested box that looked like a stray rectangle. Works in light/dark. */
.kanban-column-todo .kanban-column-header:has(.kanban-column-header-main-clickable:hover) {
  background-color: color-mix(in srgb, var(--dp-accent) 12%, var(--dp-bg-card));
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--dp-accent) 40%, transparent);
}

.kanban-column-in-progress .kanban-column-header:has(.kanban-column-header-main-clickable:hover) {
  background-color: color-mix(in srgb, var(--dp-warning) 14%, var(--dp-bg-card));
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--dp-warning) 45%, transparent);
}

.kanban-column-done .kanban-column-header:has(.kanban-column-header-main-clickable:hover) {
  background-color: color-mix(in srgb, var(--dp-success) 14%, var(--dp-bg-card));
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--dp-success) 45%, transparent);
}

.kanban-column-header-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
  padding: 0;
  border: none;
  background: transparent;
  text-align: left;
  outline: none;
}

.kanban-column-header-main-clickable {
  min-height: 44px;
  border-radius: 0.5rem;
  cursor: pointer;
}

.kanban-column-todo .kanban-column-header-main-clickable:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 3px;
}

.kanban-column-in-progress .kanban-column-header-main-clickable:focus-visible {
  outline: 2px solid var(--dp-warning);
  outline-offset: 3px;
}

.kanban-column-done .kanban-column-header-main-clickable:focus-visible {
  outline: 2px solid var(--dp-success);
  outline-offset: 3px;
}

.kanban-column-title {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.875rem;
  font-weight: 700;
  min-width: 0;
}

.kanban-column-icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.kanban-title-todo {
  color: var(--dp-accent);
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
  color: var(--dp-text-on-dark);
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
  min-height: 0;
  overflow-y: auto;
  padding-top: 0.125rem;
  padding-bottom: 0.5rem;
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
