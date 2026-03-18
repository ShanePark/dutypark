<script setup lang="ts">
import { computed } from 'vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import type { DisplayTagMember } from '@/utils/tagMembers'

type ChipVariant = 'accent' | 'subtle'
type ChipDensity = 'regular' | 'compact'
type ChipAlign = 'start' | 'end'

const props = withDefaults(defineProps<{
  members: DisplayTagMember[]
  interactive?: boolean
  buttonTitle?: string
  variant?: ChipVariant
  density?: ChipDensity
  align?: ChipAlign
  maxVisible?: number | null
}>(), {
  interactive: false,
  buttonTitle: undefined,
  variant: 'accent',
  density: 'compact',
  align: 'start',
  maxVisible: null,
})

const emit = defineEmits<{
  (e: 'chip-click', member: DisplayTagMember): void
}>()

const visibleMembers = computed(() => {
  if (props.maxVisible == null) {
    return props.members
  }
  return props.members.slice(0, props.maxVisible)
})

const hiddenCount = computed(() => {
  if (props.maxVisible == null) {
    return 0
  }
  return Math.max(props.members.length - visibleMembers.value.length, 0)
})

function handleChipClick(member: DisplayTagMember) {
  if (!props.interactive) {
    return
  }
  emit('chip-click', member)
}
</script>

<template>
  <div
    v-if="visibleMembers.length > 0 || hiddenCount > 0"
    class="member-tag-chips"
    :class="align === 'end' ? 'member-tag-chips--end' : 'member-tag-chips--start'"
  >
    <component
      v-for="member in visibleMembers"
      :key="member.key"
      :is="interactive ? 'button' : 'span'"
      :type="interactive ? 'button' : undefined"
      class="member-tag-chip"
      :class="[
        `member-tag-chip--${variant}`,
        `member-tag-chip--${density}`,
        interactive ? 'member-tag-chip--interactive' : 'member-tag-chip--static',
      ]"
      :title="interactive ? buttonTitle : undefined"
      @click="handleChipClick(member)"
    >
      <ProfileAvatar
        :member-id="member.id ?? null"
        :name="member.name"
        :has-profile-photo="member.hasProfilePhoto"
        :profile-photo-version="member.profilePhotoVersion"
        size="sm"
        class="member-tag-chip__avatar"
      />
      <span
        class="member-tag-chip__label"
        :class="density === 'regular' ? 'member-tag-chip__label--regular' : 'member-tag-chip__label--compact'"
      >
        {{ member.name }}
      </span>
    </component>

    <span
      v-if="hiddenCount > 0"
      class="member-tag-chip member-tag-chip--count"
      :class="[
        `member-tag-chip--${variant}`,
        `member-tag-chip--${density}`,
      ]"
    >
      +{{ hiddenCount }}
    </span>
  </div>
</template>

<style scoped>
.member-tag-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.member-tag-chips--end {
  justify-content: flex-end;
}

.member-tag-chip {
  display: inline-flex;
  min-width: 0;
  align-items: center;
  border-radius: 9999px;
  border: 1px solid transparent;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    box-shadow 0.15s ease,
    transform 0.15s ease;
}

.member-tag-chip--regular {
  min-height: 2.25rem;
  gap: 0.375rem;
  padding: 0.25rem 0.625rem 0.25rem 0.25rem;
  font-size: 0.875rem;
}

.member-tag-chip--compact {
  min-height: 2rem;
  gap: 0.375rem;
  padding: 0.25rem 0.5rem 0.25rem 0.25rem;
  font-size: 0.75rem;
}

.member-tag-chip--accent {
  border-color: var(--dp-accent-border);
  background-color: var(--dp-accent-soft);
  color: var(--dp-text-primary);
}

.member-tag-chip--subtle {
  border-color: var(--dp-border-primary);
  background-color: var(--dp-bg-secondary);
  color: var(--dp-text-primary);
}

.member-tag-chip--interactive {
  cursor: pointer;
  appearance: none;
}

.member-tag-chip--interactive:hover {
  background-color: var(--dp-accent-bg-hover);
  border-color: var(--dp-accent-border);
}

.member-tag-chip--interactive:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px var(--dp-accent-ring);
}

.member-tag-chip--interactive:active {
  transform: translateY(1px);
}

.member-tag-chip--count {
  justify-content: center;
  padding-left: 0.625rem;
  padding-right: 0.625rem;
  color: var(--dp-text-muted);
  font-weight: 600;
}

.member-tag-chip__label {
  display: block;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}

.member-tag-chip__label--regular {
  max-width: 8rem;
}

.member-tag-chip__label--compact {
  max-width: 8.75rem;
}
</style>
