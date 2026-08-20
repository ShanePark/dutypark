<script setup lang="ts">
import { ref, nextTick, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Home, UserMinus, Trash2, Ban, X } from 'lucide-vue-next'
import type { DashboardFriendDetail } from '@/types'

const props = defineProps<{
  friend: DashboardFriendDetail | null
  position: { top: number; left: number }
}>()

const emit = defineEmits<{
  close: []
  addFamily: []
  removeFamily: []
  unfriend: []
  block: []
}>()

const { t } = useI18n()

const menuRef = ref<HTMLElement | null>(null)
const placedPosition = ref(props.position)

// The caller anchors the menu to the top of the friend card; if the menu would then run past the
// bottom of the viewport, lift it just enough to stay fully visible.
watch(
  () => [props.friend, props.position] as const,
  ([friend, position]) => {
    if (!friend) return
    placedPosition.value = position
    nextTick(() => {
      const menu = menuRef.value
      if (!menu) return
      const anchorTop = position.top - window.scrollY
      if (anchorTop + menu.offsetHeight > window.innerHeight - 8) {
        placedPosition.value = {
          ...position,
          top: Math.max(window.scrollY + 8, window.scrollY + window.innerHeight - 8 - menu.offsetHeight),
        }
      }
    })
  },
  { immediate: true },
)
</script>

<template>
  <!-- Friend Menu (Teleported to body): bottom sheet on mobile, anchored popover on desktop -->
  <Teleport to="body">
    <Transition name="friend-menu-overlay">
      <div
        v-if="friend"
        class="friend-menu-overlay fixed inset-0 z-[9998]"
        @click.stop="emit('close')"
      />
    </Transition>
    <Transition name="friend-menu-pop">
      <div
        v-if="friend"
        ref="menuRef"
        class="friend-menu absolute w-44 rounded-xl z-[9999] overflow-hidden"
        :style="{
          top: placedPosition.top + 'px',
          left: placedPosition.left + 'px'
        }"
        @click.stop
      >
        <div class="friend-menu-header flex items-center justify-between gap-2 pl-4 pr-1.5 py-1.5">
          <span class="text-sm font-semibold truncate text-dp-text-primary">{{ friend.member.name }}</span>
          <button
            class="p-2.5 rounded-lg text-dp-text-muted hover:text-dp-text-primary hover:bg-dp-bg-hover transition cursor-pointer"
            :aria-label="t('common.actions.close')"
            @click="emit('close')"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
        <button
          v-if="!friend.isFamily"
          class="w-full min-h-[44px] px-4 py-2.5 text-left text-sm text-dp-accent hover:bg-dp-accent-soft flex items-center gap-2.5 transition cursor-pointer"
          @click="emit('addFamily')"
        >
          <Home class="w-4 h-4 flex-shrink-0" />
          {{ t('friends.actions.addFamily') }}
        </button>
        <button
          v-if="friend.isFamily"
          class="w-full min-h-[44px] px-4 py-2.5 text-left text-sm text-dp-warning hover:bg-dp-warning-soft flex items-center gap-2.5 transition cursor-pointer"
          @click="emit('removeFamily')"
        >
          <UserMinus class="w-4 h-4 flex-shrink-0" />
          {{ t('friends.actions.removeFamily') }}
        </button>
        <button
          class="w-full min-h-[44px] px-4 py-2.5 text-left text-sm text-dp-danger hover:bg-dp-danger-soft flex items-center gap-2.5 transition cursor-pointer"
          @click="emit('unfriend')"
        >
          <Trash2 class="w-4 h-4 flex-shrink-0" />
          {{ t('friends.actions.removeFriend') }}
        </button>
        <button
          class="w-full min-h-[44px] px-4 py-2.5 text-left text-sm text-dp-danger hover:bg-dp-danger-soft flex items-center gap-2.5 transition cursor-pointer"
          @click="emit('block')"
        >
          <Ban class="w-4 h-4 flex-shrink-0" />
          {{ t('friends.block.action') }}
        </button>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Dim background on mobile so the sheet stands out; transparent on desktop like NotificationDropdown */
.friend-menu-overlay {
  background-color: var(--dp-overlay-scrim-soft);
  backdrop-filter: blur(var(--dp-overlay-blur));
}

@media (min-width: 640px) {
  .friend-menu-overlay {
    background-color: transparent;
    backdrop-filter: none;
  }
}

.friend-menu {
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-primary);
  box-shadow: var(--dp-shadow-dropdown);
}

:global(.dark) .friend-menu {
  box-shadow: var(--dp-shadow-dropdown-dark);
}

.friend-menu-header {
  background-color: var(--dp-bg-tertiary);
  border-bottom: 1px solid var(--dp-border-primary);
}

.friend-menu-overlay-enter-active,
.friend-menu-overlay-leave-active {
  transition: opacity 0.2s ease;
}

.friend-menu-overlay-enter-from,
.friend-menu-overlay-leave-to {
  opacity: 0;
}

.friend-menu-pop-enter-active,
.friend-menu-pop-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}

.friend-menu-pop-enter-from,
.friend-menu-pop-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
