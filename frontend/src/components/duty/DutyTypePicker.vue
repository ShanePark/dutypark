<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref, type CSSProperties } from 'vue'
import { Check, ChevronDown } from 'lucide-vue-next'
import { useEscapeKey } from '@/composables/useEscapeKey'
import type { DutyPatternDutyTypeDto } from '@/types'

const props = defineProps<{
  modelValue: number
  options: DutyPatternDutyTypeDto[]
  visibleOptionIds: Set<number>
  label: string
  hiddenLabel: string
  closeLabel: string
  triggerId: string
  disabled?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: number]
}>()

const pickerRef = ref<HTMLDivElement | null>(null)
const triggerRef = ref<HTMLButtonElement | null>(null)
const isOpen = ref(false)
const openUpward = ref(false)
// On mobile the modal body clips absolutely-positioned menus, so the menu is
// fixed-positioned from the trigger's viewport rect instead (the invisible
// full-screen scrim blocks scrolling, keeping the anchor valid while open).
const menuStyle = ref<CSSProperties | undefined>()
const listMaxHeight = ref<string | undefined>()

function selectedOption(): DutyPatternDutyTypeDto | undefined {
  return props.options.find((option) => option.id === props.modelValue)
}

function optionDisabled(option: DutyPatternDutyTypeDto): boolean {
  return !props.visibleOptionIds.has(option.id)
}

function close({ restoreFocus = false } = {}) {
  if (!isOpen.value) return
  isOpen.value = false
  if (restoreFocus) {
    void nextTick(() => triggerRef.value?.focus())
  }
}

function toggle() {
  if (props.disabled) return
  isOpen.value = !isOpen.value
  if (isOpen.value) {
    const rect = triggerRef.value?.getBoundingClientRect()
    if (rect) {
      const estimatedMenuHeight = Math.min(props.options.length * 48 + 16, 288)
      const footerTop = document.querySelector('footer')?.getBoundingClientRect().top ?? window.innerHeight
      const spaceBelow = footerTop - rect.bottom - 8
      const spaceAbove = rect.top - 8
      openUpward.value = spaceBelow < estimatedMenuHeight && spaceAbove > spaceBelow
      if (window.matchMedia('(min-width: 640px)').matches) {
        menuStyle.value = undefined
        listMaxHeight.value = undefined
      } else {
        const available = Math.max(openUpward.value ? spaceAbove : spaceBelow, 160)
        menuStyle.value = {
          position: 'fixed',
          left: `${rect.left}px`,
          width: `${rect.width}px`,
          ...(openUpward.value
            ? { bottom: `${window.innerHeight - rect.top + 8}px` }
            : { top: `${rect.bottom + 8}px` }),
        }
        listMaxHeight.value = `${Math.min(available, 288)}px`
      }
    }
    void nextTick(() => {
      pickerRef.value
        ?.querySelector<HTMLElement>('[role="option"][aria-selected="true"]')
        ?.focus()
    })
  }
}

function select(option: DutyPatternDutyTypeDto) {
  if (optionDisabled(option)) return
  emit('update:modelValue', option.id)
  close({ restoreFocus: true })
}

function handleDocumentClick(event: MouseEvent) {
  if (!pickerRef.value?.contains(event.target as Node)) {
    close()
  }
}

// The fixed-positioned mobile menu cannot follow its trigger, so close it if
// anything outside the picker scrolls while it is open.
function handleScrollCapture(event: Event) {
  if (!menuStyle.value) return
  if (pickerRef.value?.contains(event.target as Node)) return
  close()
}

useEscapeKey(isOpen, () => close({ restoreFocus: true }))

function handleOptionKeydown(event: KeyboardEvent) {
  if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()
  const options = Array.from(
    pickerRef.value?.querySelectorAll<HTMLElement>('[role="option"]:not([aria-disabled="true"])') ?? [],
  )
  if (!options.length) return
  const currentIndex = options.indexOf(event.currentTarget as HTMLElement)
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

onMounted(() => {
  document.addEventListener('click', handleDocumentClick)
  document.addEventListener('scroll', handleScrollCapture, { capture: true, passive: true })
})

onUnmounted(() => {
  document.removeEventListener('click', handleDocumentClick)
  document.removeEventListener('scroll', handleScrollCapture, { capture: true })
})
</script>

<template>
  <div ref="pickerRef" class="relative min-w-0">
    <button
      ref="triggerRef"
      :id="triggerId"
      type="button"
      class="flex min-h-11 w-full items-center gap-3 rounded-lg border px-3 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-60 bg-dp-bg-secondary border-dp-border-primary hover:bg-dp-bg-tertiary hover:border-dp-border-hover"
      :disabled="disabled"
      aria-haspopup="listbox"
      :aria-expanded="isOpen"
      :aria-label="`${label}: ${selectedOption()?.name ?? ''}`"
      @click="toggle"
    >
      <span
        class="size-3.5 shrink-0 rounded-full border border-dp-border-secondary"
        :style="{ backgroundColor: selectedOption()?.color || 'var(--dp-duty-fallback)' }"
        aria-hidden="true"
      ></span>
      <span class="min-w-0 flex-1 truncate font-medium text-dp-text-primary">
        {{ selectedOption()?.name }}
      </span>
      <span
        v-if="selectedOption() && optionDisabled(selectedOption()!)"
        class="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold bg-dp-warning-soft text-dp-warning"
      >
        {{ hiddenLabel }}
      </span>
      <ChevronDown
        class="size-4 shrink-0 text-dp-text-muted transition-transform"
        :class="{ 'rotate-180': isOpen }"
        aria-hidden="true"
      />
    </button>

    <template v-if="isOpen">
      <button
        type="button"
        class="fixed inset-0 z-40 sm:hidden"
        :aria-label="closeLabel"
        @click.stop="close({ restoreFocus: true })"
      ></button>

      <Transition name="picker">
        <div
          class="z-50 overflow-hidden rounded-xl border shadow-xl sm:absolute sm:inset-x-0 bg-dp-bg-card border-dp-border-secondary"
          :class="openUpward
            ? 'sm:bottom-full sm:top-auto sm:mb-2 sm:mt-0'
            : 'sm:bottom-auto sm:top-full sm:mb-0 sm:mt-2'"
          :style="menuStyle"
        >
          <div
            role="listbox"
            :aria-label="label"
            class="overflow-y-auto p-2 sm:max-h-64"
            :style="listMaxHeight ? { maxHeight: listMaxHeight } : undefined"
          >
            <button
              v-for="option in options"
              :key="option.id"
              type="button"
              role="option"
              class="flex min-h-12 w-full items-center gap-3 rounded-xl px-3 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring"
              :class="[
                option.id === modelValue ? 'bg-dp-accent-soft text-dp-accent' : 'text-dp-text-primary hover:bg-dp-bg-hover',
                optionDisabled(option) ? 'cursor-not-allowed opacity-55' : 'cursor-pointer',
              ]"
              :aria-selected="option.id === modelValue"
              :aria-disabled="optionDisabled(option)"
              @click.stop="select(option)"
              @keydown="handleOptionKeydown"
            >
              <span
                class="size-4 shrink-0 rounded-full border border-dp-border-secondary"
                :style="{ backgroundColor: option.color || 'var(--dp-duty-fallback)' }"
                aria-hidden="true"
              ></span>
              <span class="min-w-0 flex-1 truncate font-medium">{{ option.name }}</span>
              <span
                v-if="optionDisabled(option)"
                class="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold bg-dp-warning-soft text-dp-warning"
              >
                {{ hiddenLabel }}
              </span>
              <Check v-if="option.id === modelValue" class="size-4 shrink-0" aria-hidden="true" />
            </button>
          </div>
        </div>
      </Transition>
    </template>
  </div>
</template>

<style scoped>
.picker-enter-active,
.picker-leave-active {
  transition: opacity 150ms ease, transform 150ms ease;
}

.picker-enter-from,
.picker-leave-to {
  opacity: 0;
  transform: translateY(-0.25rem);
}
</style>
