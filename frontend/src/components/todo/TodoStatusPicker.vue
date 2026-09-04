<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch, type CSSProperties, type Component } from 'vue'
import { ArrowRightLeft, Check, CheckCircle2, ChevronDown, Clock, ListTodo, Loader2 } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import { useEscapeKey } from '@/composables/useEscapeKey'
import type { TodoStatus } from '@/types'

const props = defineProps<{
  status: TodoStatus
  compact?: boolean
  footer?: boolean
  disabled?: boolean
}>()

const emit = defineEmits<{
  (e: 'change', status: TodoStatus): void
}>()

const { t } = useI18n()

const pickerRef = ref<HTMLDivElement | null>(null)
const triggerRef = ref<HTMLButtonElement | null>(null)
const menuRef = ref<HTMLDivElement | null>(null)
const isOpen = ref(false)
const menuStyle = ref<CSSProperties | undefined>()
const openUpward = ref(false)
const statusPickerOpenEvent = 'todo-status-picker:open'

const statusOptions = computed<Array<{ value: TodoStatus; label: string; icon: Component }>>(() => [
  { value: 'TODO', label: t('duty.todo.status.todo'), icon: ListTodo },
  { value: 'IN_PROGRESS', label: t('duty.todo.status.inProgress'), icon: Clock },
  { value: 'DONE', label: t('duty.todo.status.done'), icon: CheckCircle2 },
])

const currentStatusLabel = computed(() => {
  return statusOptions.value.find((option) => option.value === props.status)?.label ?? props.status
})

const triggerLabel = computed(() => {
  return props.footer ? t('duty.todo.actions.changeStatus') : currentStatusLabel.value
})

function positionMenu() {
  const trigger = triggerRef.value
  if (!trigger || typeof window === 'undefined') return

  const rect = trigger.getBoundingClientRect()
  const viewportPadding = 8
  const menuGap = 8
  const estimatedMenuHeight = statusOptions.value.length * 48 + 16
  const menuWidth = Math.min(
    Math.max(rect.width, 180),
    Math.max(window.innerWidth - viewportPadding * 2, rect.width),
  )
  const left = Math.min(
    Math.max(rect.left, viewportPadding),
    Math.max(viewportPadding, window.innerWidth - menuWidth - viewportPadding),
  )
  const spaceBelow = window.innerHeight - rect.bottom - menuGap
  const spaceAbove = rect.top - menuGap
  openUpward.value = spaceBelow < estimatedMenuHeight && spaceAbove > spaceBelow

  menuStyle.value = {
    position: 'fixed',
    left: `${left}px`,
    width: `${menuWidth}px`,
    ...(openUpward.value
      ? { bottom: `${Math.max(window.innerHeight - rect.top + menuGap, viewportPadding)}px` }
      : { top: `${Math.min(rect.bottom + menuGap, Math.max(viewportPadding, window.innerHeight - estimatedMenuHeight - viewportPadding))}px` }),
  }
}

function closeMenu({ restoreFocus = false } = {}) {
  if (!isOpen.value) return
  isOpen.value = false
  menuStyle.value = undefined
  if (restoreFocus) {
    void nextTick(() => triggerRef.value?.focus())
  }
}

function toggle() {
  if (props.disabled) return
  if (isOpen.value) {
    closeMenu({ restoreFocus: true })
    return
  }

  // Card triggers stop the native click so it does not open the card detail. Use a
  // separate document event to close another picker that may already be open.
  document.dispatchEvent(new CustomEvent(statusPickerOpenEvent, { detail: pickerRef.value }))
  isOpen.value = true
  void nextTick(() => {
    positionMenu()
    const selectedOption = menuRef.value
      ?.querySelector<HTMLButtonElement>(`[data-status="${props.status}"]`)
    if (!selectedOption) return

    // Focus the current option for keyboard users without allowing the browser to
    // scroll the board and make the document scroll handler dismiss the menu.
    selectedOption.focus({ preventScroll: true })
  })
}

function selectStatus(status: TodoStatus) {
  if (props.disabled) return
  if (status !== props.status) {
    emit('change', status)
  }
  closeMenu({ restoreFocus: true })
}

function handleMenuKeydown(event: KeyboardEvent) {
  if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  const options = Array.from(
    menuRef.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? [],
  )
  if (options.length === 0) return

  const currentIndex = options.indexOf(event.currentTarget as HTMLButtonElement)
  let nextIndex: number
  if (currentIndex < 0) {
    nextIndex = event.key === 'ArrowUp' || event.key === 'End' ? options.length - 1 : 0
  } else if (event.key === 'Home') {
    nextIndex = 0
  } else if (event.key === 'End') {
    nextIndex = options.length - 1
  } else if (event.key === 'ArrowDown') {
    nextIndex = (currentIndex + 1) % options.length
  } else {
    nextIndex = (currentIndex - 1 + options.length) % options.length
  }
  options[nextIndex]?.focus()
}

function handleDocumentClick(event: MouseEvent) {
  if (!isOpen.value) return
  const target = event.target as Node
  if (pickerRef.value?.contains(target) || menuRef.value?.contains(target)) return
  closeMenu()
}

function handleDocumentScroll(event: Event) {
  if (!isOpen.value) return
  const target = event.target as Node
  if (pickerRef.value?.contains(target) || menuRef.value?.contains(target)) return
  closeMenu()
}

function handleOtherPickerOpen(event: Event) {
  if ((event as CustomEvent<HTMLDivElement>).detail !== pickerRef.value) {
    closeMenu()
  }
}

useEscapeKey(isOpen, () => closeMenu({ restoreFocus: true }))

watch(() => props.disabled, (disabled) => {
  if (disabled) closeMenu()
})

onMounted(() => {
  document.addEventListener('click', handleDocumentClick)
  document.addEventListener('scroll', handleDocumentScroll, { capture: true, passive: true })
  document.addEventListener(statusPickerOpenEvent, handleOtherPickerOpen)
  window.addEventListener('resize', positionMenu)
})

onUnmounted(() => {
  document.removeEventListener('click', handleDocumentClick)
  document.removeEventListener('scroll', handleDocumentScroll, { capture: true })
  document.removeEventListener(statusPickerOpenEvent, handleOtherPickerOpen)
  window.removeEventListener('resize', positionMenu)
})
</script>

<template>
  <div
    ref="pickerRef"
    class="todo-status-picker"
    :class="{
      'todo-status-picker--compact': compact,
      'todo-status-picker--footer': footer,
    }"
  >
    <button
      ref="triggerRef"
      type="button"
      class="todo-status-picker-trigger"
      :class="[
        `todo-status-picker-trigger--${status.toLowerCase().replace('_', '-')}`,
        {
          'todo-status-picker-trigger--compact': compact,
          'todo-status-picker-trigger--footer': footer,
        },
      ]"
      :aria-label="`${t('duty.todo.actions.changeStatus')}: ${currentStatusLabel}`"
      :title="`${t('duty.todo.actions.changeStatus')}: ${currentStatusLabel}`"
      :disabled="disabled"
      :aria-busy="disabled ? 'true' : undefined"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click.stop="toggle"
    >
      <template v-if="compact">
        <span class="todo-status-picker-compact-visual" aria-hidden="true">
          <Loader2
            v-if="disabled"
            class="todo-status-picker-spinner"
          />
          <ArrowRightLeft
            v-else
            class="todo-status-picker-compact-icon"
          />
        </span>
      </template>
      <template v-else>
        <span class="todo-status-picker-label">{{ triggerLabel }}</span>
        <Loader2
          v-if="disabled"
          class="todo-status-picker-spinner"
          aria-hidden="true"
        />
        <ChevronDown
          v-else
          class="todo-status-picker-chevron"
          :class="{ 'todo-status-picker-chevron--open': isOpen }"
          aria-hidden="true"
        />
      </template>
    </button>

    <Teleport to="body">
      <div
        v-if="isOpen"
        ref="menuRef"
        class="todo-status-picker-menu"
        role="menu"
        :aria-label="t('duty.todo.actions.changeStatus')"
        :style="menuStyle"
        @click.stop
      >
        <button
          v-for="option in statusOptions"
          :key="option.value"
          type="button"
          role="menuitem"
          class="todo-status-picker-option"
          :class="[
            `todo-status-picker-option--${option.value.toLowerCase().replace('_', '-')}`,
            { 'todo-status-picker-option--selected': option.value === status },
          ]"
          :data-status="option.value"
          :aria-current="option.value === status ? 'true' : undefined"
          @click.stop="selectStatus(option.value)"
          @keydown="handleMenuKeydown"
        >
          <component :is="option.icon" class="todo-status-picker-option-icon" aria-hidden="true" />
          <span>{{ option.label }}</span>
          <Check
            v-if="option.value === status"
            class="todo-status-picker-option-check"
            aria-hidden="true"
          />
        </button>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.todo-status-picker {
  position: relative;
  display: inline-flex;
  min-width: 0;
}

.todo-status-picker--compact {
  width: 1.75rem;
  height: 1.75rem;
  flex-shrink: 0;
}

.todo-status-picker-trigger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.3rem;
  min-height: 2.75rem;
  max-width: 100%;
  padding: 0.375rem 0.625rem;
  border: 1px solid transparent;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}

.todo-status-picker--footer {
  width: 100%;
  min-width: 0;
}

.todo-status-picker-trigger--footer {
  width: 100%;
  min-width: 0;
  padding-inline: 0.5rem;
  border-radius: 0.5rem;
}

@media (min-width: 640px) {
  .todo-status-picker--footer,
  .todo-status-picker-trigger--footer {
    width: auto;
  }
}

.todo-status-picker-trigger:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 2px;
}

.todo-status-picker-trigger:disabled {
  cursor: wait;
  opacity: 0.7;
}

.todo-status-picker-trigger--todo {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-tertiary);
  border-color: var(--dp-border-primary);
}

.todo-status-picker-trigger--todo:hover {
  background-color: var(--dp-accent-bg);
  border-color: var(--dp-accent-border);
}

.todo-status-picker-trigger--in-progress {
  color: var(--dp-warning);
  background-color: var(--dp-warning-bg);
  border-color: var(--dp-warning-border);
}

.todo-status-picker-trigger--in-progress:hover {
  border-color: var(--dp-warning);
}

.todo-status-picker-trigger--done {
  color: var(--dp-success);
  background-color: var(--dp-success-bg);
  border-color: var(--dp-success-border);
}

.todo-status-picker-trigger--done:hover {
  border-color: var(--dp-success);
}

.todo-status-picker-trigger--compact {
  position: absolute;
  top: 50%;
  right: -0.5rem;
  width: 2.75rem;
  min-width: 2.75rem;
  height: 2.75rem;
  min-height: 2.75rem;
  padding: 0;
  border-color: transparent;
  border-radius: 0.5rem;
  background-color: transparent;
  transform: translateY(-50%);
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--todo {
  color: var(--dp-accent);
}

.todo-status-picker-trigger--compact .todo-status-picker-compact-visual {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  padding: 0.25rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.5rem;
  background-color: transparent;
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--todo:hover {
  background-color: transparent;
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--todo:hover .todo-status-picker-compact-visual {
  background-color: var(--dp-accent-bg);
  border-color: var(--dp-accent-border);
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--in-progress {
  color: var(--dp-warning);
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--in-progress:hover {
  background-color: transparent;
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--in-progress:hover .todo-status-picker-compact-visual {
  background-color: var(--dp-warning-bg);
  border-color: var(--dp-warning);
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--done {
  color: var(--dp-success);
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--done:hover {
  background-color: transparent;
}

.todo-status-picker-trigger--compact.todo-status-picker-trigger--done:hover .todo-status-picker-compact-visual {
  background-color: var(--dp-success-bg);
  border-color: var(--dp-success);
}

.todo-status-picker-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.todo-status-picker-trigger--footer .todo-status-picker-label {
  min-width: 0;
  overflow: visible;
  overflow-wrap: anywhere;
  text-overflow: clip;
  white-space: normal;
  text-align: center;
  line-height: 1.15;
}

.todo-status-picker-chevron {
  width: 0.9rem;
  height: 0.9rem;
  flex-shrink: 0;
  transition: transform 0.15s ease;
}

.todo-status-picker-chevron--open {
  transform: rotate(180deg);
}

.todo-status-picker-compact-icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.todo-status-picker-spinner {
  width: 0.9rem;
  height: 0.9rem;
  flex-shrink: 0;
  animation: todo-status-picker-spin 0.8s linear infinite;
}

@keyframes todo-status-picker-spin {
  to {
    transform: rotate(360deg);
  }
}

.todo-status-picker-menu {
  z-index: 10000;
  overflow: hidden;
  max-height: min(18rem, calc(100vh - 1rem));
  padding: 0.5rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.75rem;
  background-color: var(--dp-bg-card);
  box-shadow: var(--dp-shadow-lg);
}

.todo-status-picker-option {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  width: 100%;
  min-height: 2.75rem;
  padding: 0.5rem 0.625rem;
  border: 0;
  border-radius: 0.5rem;
  color: var(--dp-text-primary);
  background: transparent;
  font-size: 0.8125rem;
  text-align: left;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.todo-status-picker-option:hover,
.todo-status-picker-option:focus-visible {
  background-color: var(--dp-bg-hover);
  outline: none;
}

.todo-status-picker-option--selected {
  font-weight: 700;
}

.todo-status-picker-option--todo.todo-status-picker-option--selected {
  color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
}

.todo-status-picker-option--in-progress.todo-status-picker-option--selected {
  color: var(--dp-warning);
  background-color: var(--dp-warning-bg);
}

.todo-status-picker-option--done.todo-status-picker-option--selected {
  color: var(--dp-success);
  background-color: var(--dp-success-bg);
}

.todo-status-picker-option-icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.todo-status-picker-option-check {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
  margin-left: auto;
}
</style>
