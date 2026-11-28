<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, shallowRef, watch } from 'vue'
import { memberInitials } from '@/utils/memberName'

const props = defineProps<{ name: string }>()

// A member name for a narrow slot. It draws the full name and switches to the
// initials only while the full name overflows the slot; a name without initials
// stays whole for the slot's own ellipsis. The slot's class supplies the
// overflow styles (overflow: hidden, nowrap) this relies on.
const label = shallowRef<HTMLElement | null>(null)
const initials = computed(() => memberInitials(props.name))
const abbreviated = ref(false)
const text = computed(() => (abbreviated.value && initials.value) || props.name)

let measuring = 0

async function update() {
  const token = ++measuring
  const node = label.value
  if (!node || !initials.value) {
    abbreviated.value = false
    return
  }
  // Only the full name tells whether it fits, so draw it again before measuring.
  // Both steps run before the next paint, so the swap never flickers.
  if (abbreviated.value) {
    abbreviated.value = false
    await nextTick()
    if (token !== measuring) return
  }
  abbreviated.value = node.scrollWidth > node.clientWidth
}

let observer: ResizeObserver | null = null

onMounted(() => {
  const node = label.value
  if (typeof ResizeObserver === 'undefined' || !node) return
  observer = new ResizeObserver(() => { void update() })
  observer.observe(node)
  // The label can stay the same width while its slot grows back.
  if (node.parentElement) observer.observe(node.parentElement)
  void update()
})

watch(() => props.name, () => { void update() }, { flush: 'post' })

onUnmounted(() => {
  observer?.disconnect()
  observer = null
})
</script>

<template>
  <span ref="label" :title="text !== name ? name : undefined">{{ text }}</span>
</template>
