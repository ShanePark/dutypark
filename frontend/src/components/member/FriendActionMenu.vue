<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { Home, UserMinus, Trash2, Ban, X } from '@lucide/vue'
import type { DashboardFriendDetail } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

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
const closeButtonRef = ref<HTMLButtonElement | null>(null)
const placedPosition = ref(props.position)
const isOpen = computed({
  get: () => props.friend !== null,
  set: () => undefined,
})
let previouslyFocused: HTMLElement | null = null
let shouldRestoreFocus = true

useBodyScrollLock(isOpen)
useEscapeKey(isOpen, requestClose)

const menuTitleId = computed(() => {
  const memberId = props.friend?.member.id ?? 'unknown'
  return `friend-action-menu-title-${memberId}`
})

// The caller anchors the desktop menu to the top of the friend card. On small screens the CSS
// turns the same element into a bottom sheet, so the calculated desktop position is ignored.
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

watch(
  () => props.friend,
  (friend, previousFriend) => {
    if (friend && !previousFriend) {
      shouldRestoreFocus = true
      if (typeof document !== 'undefined') {
        previouslyFocused = document.activeElement instanceof HTMLElement
          ? document.activeElement
          : null
      }
      nextTick(() => closeButtonRef.value?.focus())
      return
    }

    if (!friend && previousFriend) {
      const target = previouslyFocused
      previouslyFocused = null
      if (shouldRestoreFocus && target?.isConnected) {
        nextTick(() => target.focus())
      }
    }
  },
)

function requestClose() {
  shouldRestoreFocus = true
  emit('close')
}

// Actions open a confirmation dialog immediately after the parent closes this menu. Do not move
// focus back to the card in that path or the confirmation dialog would lose keyboard focus.
function runAction(action: 'addFamily' | 'removeFamily' | 'unfriend' | 'block') {
  shouldRestoreFocus = false
  switch (action) {
    case 'addFamily':
      emit('addFamily')
      break
    case 'removeFamily':
      emit('removeFamily')
      break
    case 'unfriend':
      emit('unfriend')
      break
    case 'block':
      emit('block')
      break
  }
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key !== 'Tab') return

  const focusable = Array.from(
    menuRef.value?.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    ) ?? [],
  )
  if (focusable.length === 0) {
    event.preventDefault()
    menuRef.value?.focus()
    return
  }

  const first = focusable[0]
  const last = focusable[focusable.length - 1]
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last?.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first?.focus()
  }
}

onUnmounted(() => {
  if (shouldRestoreFocus && previouslyFocused?.isConnected) {
    previouslyFocused.focus()
  }
})
</script>

<template>
  <!-- Friend Menu (Teleported to body): bottom sheet on mobile, anchored action panel on desktop -->
  <Teleport to="body">
    <Transition name="friend-menu-overlay">
      <div
        v-if="friend"
        class="friend-menu-overlay fixed inset-0 z-[9998]"
        @click.stop="requestClose"
      />
    </Transition>
    <Transition name="friend-menu-pop">
      <div
        v-if="friend"
        ref="menuRef"
        class="friend-menu z-[9999] overflow-y-auto rounded-2xl"
        :style="{
          top: placedPosition.top + 'px',
          left: placedPosition.left + 'px',
        }"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="menuTitleId"
        tabindex="-1"
        @click.stop
        @keydown="handleKeydown"
      >
        <div class="friend-menu-grabber" aria-hidden="true">
          <span />
        </div>

        <div class="friend-menu-header flex items-center justify-between gap-3 px-4 py-3">
          <div class="flex min-w-0 items-center gap-3">
            <ProfileAvatar
              :member-id="friend.member.id"
              :name="friend.member.name"
              :has-profile-photo="friend.member.hasProfilePhoto"
              :profile-photo-version="friend.member.profilePhotoVersion"
              size="md"
            />
            <div class="min-w-0">
              <span :id="menuTitleId" class="block truncate text-sm font-semibold text-dp-text-primary">
                {{ friend.member.name }}
              </span>
              <span v-if="friend.isFamily" class="mt-0.5 flex items-center gap-1 text-xs text-dp-warning">
                <Home class="h-3 w-3" aria-hidden="true" />
                {{ t('friends.labels.familyMember') }}
              </span>
            </div>
          </div>
          <button
            ref="closeButtonRef"
            type="button"
            class="grid h-11 w-11 shrink-0 place-items-center rounded-xl text-dp-text-muted transition hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
            :aria-label="t('common.actions.close')"
            @click="requestClose"
          >
            <X class="h-5 w-5" aria-hidden="true" />
          </button>
        </div>

        <div class="friend-menu-actions">
          <button
            v-if="!friend.isFamily"
            type="button"
            class="friend-menu-action flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-dp-accent transition hover:bg-dp-accent-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
            @click="runAction('addFamily')"
          >
            <Home class="h-5 w-5 shrink-0" aria-hidden="true" />
            {{ t('friends.actions.addFamily') }}
          </button>
          <button
            v-if="friend.isFamily"
            type="button"
            class="friend-menu-action flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-dp-warning transition hover:bg-dp-warning-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
            @click="runAction('removeFamily')"
          >
            <UserMinus class="h-5 w-5 shrink-0" aria-hidden="true" />
            {{ t('friends.actions.removeFamily') }}
          </button>
        </div>

        <div class="friend-menu-danger-actions">
          <button
            type="button"
            class="friend-menu-action flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-dp-danger transition hover:bg-dp-danger-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
            @click="runAction('unfriend')"
          >
            <Trash2 class="h-5 w-5 shrink-0" aria-hidden="true" />
            {{ t('friends.actions.removeFriend') }}
          </button>
          <button
            type="button"
            class="friend-menu-action flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-dp-danger transition hover:bg-dp-danger-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
            @click="runAction('block')"
          >
            <Ban class="h-5 w-5 shrink-0" aria-hidden="true" />
            {{ t('friends.block.action') }}
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.friend-menu-overlay {
  background-color: var(--dp-overlay-scrim-soft);
  backdrop-filter: blur(var(--dp-overlay-blur));
}

.friend-menu {
  position: absolute;
  width: 15rem;
  max-width: calc(100vw - 1rem);
  max-height: calc(100vh - 1rem);
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-primary);
  box-shadow: var(--dp-shadow-dropdown);
  overscroll-behavior: contain;
}

:global(.dark) .friend-menu {
  box-shadow: var(--dp-shadow-dropdown-dark);
}

.friend-menu-header {
  background-color: var(--dp-bg-tertiary);
  border-bottom: 1px solid var(--dp-border-primary);
}

.friend-menu-grabber {
  display: none;
}

.friend-menu-action {
  min-height: 3rem;
}

.friend-menu-danger-actions {
  margin-top: 0.25rem;
  border-top: 1px solid var(--dp-border-primary);
}

@media (min-width: 640px) {
  .friend-menu-overlay {
    background-color: transparent;
    backdrop-filter: none;
  }
}

@media (max-width: 639px) {
  .friend-menu {
    position: fixed !important;
    inset: auto 0 0 !important;
    width: 100%;
    max-width: none;
    max-height: min(80dvh, 34rem);
    padding-bottom: max(0.75rem, env(safe-area-inset-bottom));
    border-right: 0;
    border-bottom: 0;
    border-left: 0;
    border-radius: 1.5rem 1.5rem 0 0;
    box-shadow: var(--dp-shadow-dropdown);
  }

  .friend-menu-grabber {
    display: flex;
    justify-content: center;
    padding: 0.625rem 0 0.125rem;
  }

  .friend-menu-grabber span {
    width: 2.5rem;
    height: 0.25rem;
    border-radius: 9999px;
    background-color: var(--dp-border-secondary);
  }

  .friend-menu-header {
    padding-top: 0.5rem;
    padding-bottom: 0.75rem;
  }

  .friend-menu-action {
    min-height: 3.25rem;
    padding-top: 0.75rem;
    padding-bottom: 0.75rem;
  }

  .friend-menu-danger-actions {
    margin-top: 0.5rem;
    padding-top: 0.5rem;
  }
}

.friend-menu-overlay-enter-active,
.friend-menu-overlay-leave-active {
  transition: opacity 0.2s ease;
}

.friend-menu-overlay-leave-active {
  pointer-events: none;
}

.friend-menu-overlay-enter-from,
.friend-menu-overlay-leave-to {
  opacity: 0;
}

.friend-menu-pop-enter-active,
.friend-menu-pop-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}

.friend-menu-pop-enter-from,
.friend-menu-pop-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

@media (max-width: 639px) {
  .friend-menu-pop-enter-from,
  .friend-menu-pop-leave-to {
    transform: translateY(100%);
  }
}

@media (prefers-reduced-motion: reduce) {
  .friend-menu-overlay-enter-active,
  .friend-menu-overlay-leave-active,
  .friend-menu-pop-enter-active,
  .friend-menu-pop-leave-active {
    transition: none;
  }
}
</style>
