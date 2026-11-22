<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import type { DisplayTagMember } from '@/utils/tagMembers'
import {
  calendarSpanCompactMore,
  calendarSpanDayAt,
  calendarSpanTitleFloor,
  fitCalendarSpanTags,
  type CalendarSpanTagFit,
  type CalendarSpanTagScale,
} from '@/utils/calendarSpanTagFit'

const props = defineProps<{
  tags: DisplayTagMember[]
  title: string
  formatLabel: (name: string) => string
}>()

// The tag cluster of a multi-day ribbon. It sits in the ribbon's flex row and
// shows the richest level that fits beside the title's minimum width, and at
// least the first member's avatar whenever the band can hold one.
const root = ref<HTMLElement | null>(null)
const measure = ref<HTMLElement | null>(null)
const fit = ref<CalendarSpanTagFit>({ level: 'none', shown: 0 })
const hidden = computed(() => props.tags.length - fit.value.shown)
// The covered day under each drawn chip, avatar and pill, in order. A cluster
// can stretch over several days, so each item takes that day's ink and ring.
const dayUnder = ref<number[]>([])
function itemStyle(index: number) {
  const day = dayUnder.value[index]
  if (day === undefined) return undefined
  return { '--calendar-ink': `var(--calendar-span-ink-${day})`, '--calendar-span-ring': `var(--calendar-span-glass-${day})` }
}

const width = (element: Element | null | undefined) => element?.getBoundingClientRect().width ?? 0

// Icons inside the title (visibility, details) stay when its text is cut.
function iconsWidth(title: HTMLElement | null): number {
  return Array.from(title?.children ?? []).reduce((sum, icon) => {
    const style = getComputedStyle(icon)
    return sum + width(icon) + parseFloat(style.marginLeft) + parseFloat(style.marginRight)
  }, 0)
}

function update() {
  const cluster = root.value
  const ribbon = cluster?.parentElement
  const probe = measure.value
  if (!cluster || !ribbon || !probe) return
  const ribbonStyle = getComputedStyle(ribbon)
  const ribbonWidth = width(ribbon)
  if (ribbonWidth === 0) return

  const scale: CalendarSpanTagScale = window.matchMedia('(min-width: 640px)').matches ? 'pc' : 'mobile'
  const title = ribbon.querySelector<HTMLElement>('.calendar-span__title')
  const items = Array.from(ribbon.children).filter((item) => {
    const style = getComputedStyle(item)
    return style.display !== 'none' && style.position !== 'absolute'
  })
  const others = items.reduce((sum, item) => (item === cluster || item === title ? sum : sum + width(item)), 0)
  const available = ribbonWidth
    - parseFloat(ribbonStyle.paddingLeft) - parseFloat(ribbonStyle.paddingRight)
    - others - (parseFloat(ribbonStyle.columnGap) || 0) * (items.length - 1)
  const titleWidth = title?.scrollWidth ?? 0
  const [firstAvatar, secondAvatar] = Array.from(probe.querySelectorAll('.span-tag-stack .span-tag-avatar'))

  const next = fitCalendarSpanTags({
    available: Math.floor(available),
    titleMin: Math.ceil(Math.min(
      titleWidth,
      width(probe.querySelector(`[data-title-prefix="${scale}"]`)) + iconsWidth(title),
    )),
    chipWidths: Array.from(probe.querySelectorAll('.span-tag-chip'), (chip) => Math.ceil(width(chip))),
    avatarSize: Math.ceil(width(firstAvatar)),
    avatarStep: (secondAvatar?.getBoundingClientRect().left ?? 0) - (firstAvatar?.getBoundingClientRect().left ?? 0),
    moreWidth: Math.ceil(width(probe.querySelector('.span-tag-pill:not(.span-tag-pill--compact)'))),
    compactWidth: Math.ceil(width(probe.querySelector('.span-tag-pill--compact'))),
    loneWidth: Math.ceil(width(probe.querySelector('.span-tag-lone'))),
    gap: parseFloat(getComputedStyle(cluster).columnGap) || 0,
    scale,
  })
  if (next.level !== fit.value.level || next.shown !== fit.value.shown) fit.value = next
  nextTick(placeItems)
}

function placeItems() {
  const cluster = root.value
  const ribbon = cluster?.parentElement
  if (!cluster || !ribbon) return
  const style = getComputedStyle(ribbon)
  const px = (name: string) => parseFloat(style.getPropertyValue(name)) || 0
  const box = ribbon.getBoundingClientRect()
  const band = {
    width: box.width,
    start: px('--calendar-span-start'),
    end: px('--calendar-span-end'),
    gap: px('--calendar-gap'),
    days: px('--calendar-span-days') || 1,
  }
  const next = Array.from(cluster.querySelectorAll('[data-span-tag-item]'), (item) => {
    const rect = item.getBoundingClientRect()
    return calendarSpanDayAt(rect.left + rect.width / 2 - box.left, band)
  })
  if (next.join() !== dayUnder.value.join()) dayUnder.value = next
}

let observer: ResizeObserver | null = null

onMounted(() => {
  // The host renderer used by unit tests has no layout to measure.
  const ribbon = root.value?.parentElement
  if (typeof ResizeObserver === 'undefined' || !ribbon) return
  update()
  observer = new ResizeObserver(update)
  observer.observe(ribbon)
  document.fonts?.ready.then(update)
})

watch(() => [props.tags, props.title], update, { flush: 'post' })

onUnmounted(() => {
  observer?.disconnect()
  observer = null
})
</script>

<template>
  <span ref="root" class="calendar-span__tags" aria-hidden="true">
    <template v-if="fit.level === 'chips'">
      <span
        v-for="(tag, index) in tags.slice(0, fit.shown)"
        :key="tag.key"
        class="span-tag-chip"
        data-span-tag-item
        :style="itemStyle(index)"
      >
        <ProfileAvatar
          :member-id="tag.id ?? null"
          :name="tag.name"
          :has-profile-photo="tag.hasProfilePhoto"
          :profile-photo-version="tag.profilePhotoVersion"
          size="xs"
          class="span-tag-avatar"
        />
        <span class="span-tag-chip__label">{{ formatLabel(tag.name) }}</span>
      </span>
    </template>
    <span v-else-if="fit.level === 'avatars'" class="span-tag-stack">
      <ProfileAvatar
        v-for="(tag, index) in tags.slice(0, fit.shown)"
        :key="tag.key"
        :member-id="tag.id ?? null"
        :name="tag.name"
        :has-profile-photo="tag.hasProfilePhoto"
        :profile-photo-version="tag.profilePhotoVersion"
        size="xs"
        class="span-tag-avatar"
        data-span-tag-item
        :style="itemStyle(index)"
      />
    </span>
    <span
      v-else-if="fit.level === 'lone'"
      class="span-tag-lone"
      data-span-tag-item
      :style="itemStyle(0)"
    >
      <ProfileAvatar
        :member-id="tags[0]!.id ?? null"
        :name="tags[0]!.name"
        :has-profile-photo="tags[0]!.hasProfilePhoto"
        :profile-photo-version="tags[0]!.profilePhotoVersion"
        size="xs"
        class="span-tag-avatar"
      />
      <span v-if="tags.length > 1" class="span-tag-lone__more">{{ calendarSpanCompactMore(tags.length) }}</span>
    </span>
    <span
      v-if="fit.level === 'compact'"
      class="span-tag-pill span-tag-pill--compact"
      data-span-tag-item
      :style="itemStyle(0)"
    >
      <ProfileAvatar
        :member-id="tags[0]!.id ?? null"
        :name="tags[0]!.name"
        :has-profile-photo="tags[0]!.hasProfilePhoto"
        :profile-photo-version="tags[0]!.profilePhotoVersion"
        size="xs"
        class="span-tag-avatar"
      />
      <span v-if="tags.length > 1" class="span-tag-pill__more">{{ calendarSpanCompactMore(tags.length) }}</span>
    </span>
    <span
      v-else-if="(fit.level === 'chips' || fit.level === 'avatars') && hidden > 0"
      class="span-tag-pill"
      data-span-tag-item
      :style="itemStyle(fit.shown)"
    >+{{ hidden }}</span>

    <!-- Invisible copies of every level, measured to choose the one that fits. -->
    <span ref="measure" class="span-tags-measure">
      <span v-for="tag in tags" :key="tag.key" class="span-tag-chip">
        <span class="span-tag-avatar" />
        <span class="span-tag-chip__label">{{ formatLabel(tag.name) }}</span>
      </span>
      <span class="span-tag-stack"><span class="span-tag-avatar" /><span class="span-tag-avatar" /></span>
      <span class="span-tag-pill">+{{ tags.length }}</span>
      <span class="span-tag-pill span-tag-pill--compact">
        <span class="span-tag-avatar" />
        <span v-if="tags.length > 1" class="span-tag-pill__more">{{ calendarSpanCompactMore(tags.length) }}</span>
      </span>
      <span class="span-tag-lone">
        <span class="span-tag-avatar" />
        <span v-if="tags.length > 1" class="span-tag-lone__more">{{ calendarSpanCompactMore(tags.length) }}</span>
      </span>
      <span class="span-tag-title" data-title-prefix="pc">{{ calendarSpanTitleFloor(title, 'pc') }}</span>
      <span class="span-tag-title" data-title-prefix="mobile">{{ calendarSpanTitleFloor(title, 'mobile') }}</span>
    </span>
  </span>
</template>

<style scoped>
/* Fills the ribbon's free space and right-aligns its content, so the end time
   and chevron follow it directly. It never shrinks: the title gives way. Until
   its items are placed over their days, it takes the ink of the band's last day. */
.calendar-span__tags {
  --calendar-ink: var(--calendar-span-end-ink);

  display: flex;
  flex: 1 0 auto;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  min-width: 0;
}

.span-tags-measure {
  position: absolute;
  top: 0;
  left: 0;
  display: flex;
  gap: 2px;
  visibility: hidden;
}

.span-tag-title {
  font-weight: 700;
}

.span-tag-chip {
  display: inline-flex;
  flex: none;
  align-items: center;
  box-sizing: border-box;
  height: 13px;
  gap: 0.04rem;
  padding: 0 3px 0 0.04rem;
  border-radius: 9999px;
  background: color-mix(in srgb, var(--calendar-ink) 9%, transparent);
  color: color-mix(in srgb, var(--calendar-ink) 80%, transparent);
  font-size: 8.5px;
  line-height: 1;
}

.span-tag-chip__label {
  max-width: 3em;
  overflow: hidden;
  text-overflow: ellipsis;
  letter-spacing: -0.05em;
}

.span-tag-avatar {
  flex: none;
  box-sizing: border-box;
  width: 13px;
  height: 13px;
  border-radius: 9999px;
}

.span-tag-chip .span-tag-avatar {
  width: 10px;
  height: 10px;
}

/* Rings match the band over the tile, never a stark white. */
.span-tag-chip .span-tag-avatar.profile-avatar {
  border: 1px solid var(--calendar-span-ring);
}

.span-tag-stack {
  display: inline-flex;
  flex: none;
  align-items: center;
}

.span-tag-stack .span-tag-avatar + .span-tag-avatar {
  margin-left: -5px;
}

.span-tag-stack .span-tag-avatar.profile-avatar,
.span-tag-lone .span-tag-avatar.profile-avatar {
  border: 0;
  box-shadow: 0 0 0 1.5px var(--calendar-span-ring);
}

.span-tag-pill {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  height: 13px;
  gap: 2px;
  padding: 0 3px;
  border-radius: 9999px;
  background: color-mix(in srgb, var(--calendar-ink) 10%, transparent);
  color: color-mix(in srgb, var(--calendar-ink) 76%, transparent);
  font-size: 8px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: normal;
  line-height: 1;
}

/* The lone avatar counts the other members in a notification-style badge on
   its bottom-right corner. The badge overhangs the avatar, and the padding
   reserves that overhang so the band never clips it. */
.span-tag-lone {
  position: relative;
  display: inline-flex;
  flex: none;
  align-items: center;
}

.span-tag-lone:has(.span-tag-lone__more) {
  padding-right: 4px;
}

.span-tag-lone__more {
  position: absolute;
  right: 0;
  bottom: -1px;
  box-sizing: border-box;
  min-width: 9px;
  height: 9px;
  padding: 0 1.5px;
  border-radius: 9999px;
  background: color-mix(in srgb, var(--calendar-ink) 85%, var(--calendar-span-ring));
  box-shadow: 0 0 0 1px var(--calendar-span-ring);
  color: var(--calendar-span-ring);
  font-size: 7px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;
  line-height: 9px;
  text-align: center;
}

/* The first member's avatar sits inside the pill, inset evenly; the "+N"
   after it keeps the pill's usual right padding. */
.span-tag-pill--compact {
  padding: 0 1.5px;
}

.span-tag-pill__more {
  padding-right: 1.5px;
}

.span-tag-pill--compact .span-tag-avatar {
  width: 10px;
  height: 10px;
}

@media (min-width: 640px) {
  .span-tag-chip {
    height: 19px;
    gap: 0.1rem;
    padding: 0 5px 0 0.1rem;
    font-size: 11.5px;
  }

  .span-tag-avatar {
    width: 18px;
    height: 18px;
  }

  .span-tag-chip .span-tag-avatar {
    width: 15px;
    height: 15px;
  }

  .span-tag-pill {
    height: 18px;
    padding: 0 5px;
    font-size: 10.5px;
  }

  .span-tag-pill--compact {
    padding: 0 2px;
  }

  .span-tag-pill__more {
    padding-right: 3px;
  }

  .span-tag-pill--compact .span-tag-avatar {
    width: 14px;
    height: 14px;
  }

  .span-tag-lone:has(.span-tag-lone__more) {
    padding-right: 5px;
  }

  .span-tag-lone__more {
    min-width: 11px;
    height: 11px;
    padding: 0 2px;
    font-size: 8.5px;
    line-height: 11px;
  }
}
</style>
