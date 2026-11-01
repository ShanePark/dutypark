<script setup lang="ts">
import { Lock, Plus, Star } from '@lucide/vue'
import { useI18n } from 'vue-i18n'
import { parseDateOnly } from '@/utils/date'
import type { LocalDDay } from '@/views/duty/dutyViewTypes'

const props = defineProps<{
  dDays: LocalDDay[]
  pinnedDDayId: number | null
  isMyCalendar: boolean
}>()

const emit = defineEmits<{
  (e: 'open-detail', dday: LocalDDay): void
  (e: 'toggle-pin', dday: LocalDDay): void
  (e: 'add'): void
}>()

const { t, locale } = useI18n()

// State only changes colour; every row keeps the same geometry.
function stateClass(calc: number): string {
  if (calc < 0) return 'dday-row--past'
  if (calc <= 3) return 'dday-row--urgent'
  if (calc <= 14) return 'dday-row--soon'
  return 'dday-row--future'
}

function formatDate(dateStr: string): string {
  const [year = '', month = '', day = ''] = dateStr.split('-')
  const weekday = parseDateOnly(dateStr).toLocaleDateString(locale.value, { weekday: 'short' })
  return `${year}.${month}.${day} (${weekday})`
}

function isPinned(dday: LocalDDay): boolean {
  return props.pinnedDDayId === dday.id
}
</script>

<template>
  <section
    v-if="dDays.length > 0 || isMyCalendar"
    class="dday-section"
    data-testid="dday-section"
    aria-labelledby="dday-section-heading"
  >
    <div class="dday-section__header">
      <h3 id="dday-section-heading" class="dday-section__title">
        {{ t('duty.ddayList.title') }}
        <span class="dday-section__count" data-testid="dday-count">{{ dDays.length }}</span>
      </h3>
      <button
        v-if="isMyCalendar"
        type="button"
        class="dday-section__add"
        data-testid="dday-add"
        :title="t('duty.ddayList.add')"
        :aria-label="t('duty.ddayList.add')"
        @click="emit('add')"
      >
        <Plus class="dday-section__add-icon" aria-hidden="true" />
        {{ t('duty.ddayList.addShort') }}
      </button>
    </div>

    <ul v-if="dDays.length > 0" class="dday-list">
      <li
        v-for="dday in dDays"
        :key="dday.id"
        class="dday-row"
        :class="[stateClass(dday.calc), { 'is-pinned': isPinned(dday) }]"
        data-testid="dday-row"
      >
        <button
          type="button"
          class="dday-row__open"
          data-testid="dday-open"
          @click="emit('open-detail', dday)"
        >
          <span class="dday-row__value" data-testid="dday-value">{{ dday.dDayText }}</span>
          <span class="dday-row__lock" data-testid="dday-lock-slot">
            <Lock v-if="dday.isPrivate" class="dday-row__lock-icon" aria-hidden="true" />
          </span>
          <span class="dday-row__title" data-testid="dday-title" :title="dday.title">{{ dday.title }}</span>
          <span class="dday-row__date" data-testid="dday-date">{{ formatDate(dday.date) }}</span>
        </button>
        <button
          type="button"
          class="dday-row__pin"
          data-testid="dday-pin"
          :aria-pressed="isPinned(dday)"
          :title="isPinned(dday) ? t('duty.ddayList.unpin') : t('duty.ddayList.pinToCalendar')"
          :aria-label="isPinned(dday) ? t('duty.ddayList.unpin') : t('duty.ddayList.pinToCalendar')"
          @click.stop="emit('toggle-pin', dday)"
        >
          <Star class="dday-row__pin-icon" aria-hidden="true" />
        </button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.dday-section {
  margin-top: 1.25rem;
}

.dday-section__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 0 2px 0.625rem;
}

.dday-section__title {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
  margin: 0;
  font-size: 17px;
  font-weight: 700;
  color: var(--dp-text-primary);
}

.dday-section__count {
  font-size: 13px;
  font-weight: 400;
  color: var(--dp-text-muted);
  font-variant-numeric: tabular-nums;
}

.dday-section__add {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 30px;
  padding: 0 10px;
  border-radius: 6px;
  background: var(--dp-bg-tertiary);
  color: var(--dp-text-primary);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.dday-section__add:hover {
  background: var(--dp-bg-hover);
}

.dday-section__add-icon {
  width: 14px;
  height: 14px;
}

.dday-list {
  margin: 0;
  padding: 0;
  list-style: none;
  overflow: hidden;
  border: 1px solid var(--dp-border-primary);
  border-radius: 6px;
  background: var(--dp-bg-card);
}

/* Mobile (<640px): D-N | lock | title over date | star, fixed 58px row. */
.dday-row {
  position: relative;
  display: flex;
  align-items: stretch;
  height: 58px;
  transition: background-color 0.15s ease;
}

.dday-row + .dday-row::before {
  content: '';
  position: absolute;
  top: 0;
  left: 14px;
  right: 0;
  height: 1px;
  background: var(--dp-border-primary);
}

.dday-row.is-pinned::after {
  content: '';
  position: absolute;
  left: 0;
  top: 12px;
  bottom: 12px;
  width: 3px;
  border-radius: 0 2px 2px 0;
  background: var(--dp-warning);
}

.dday-row__open {
  display: grid;
  flex: 1 1 auto;
  min-width: 0;
  grid-template-columns: 60px 13px minmax(0, 1fr);
  grid-template-rows: auto auto;
  align-content: center;
  align-items: center;
  column-gap: 6px;
  row-gap: 3px;
  padding: 0 0 0 14px;
  text-align: left;
  color: var(--dp-text-primary);
  cursor: pointer;
}

.dday-row__value {
  grid-column: 1;
  grid-row: 1 / 3;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
  overflow: hidden;
  text-overflow: ellipsis;
}

.dday-row__lock {
  grid-column: 2;
  grid-row: 1;
  display: flex;
  align-items: center;
  color: var(--dp-text-muted);
}

.dday-row__lock-icon {
  width: 13px;
  height: 13px;
}

.dday-row__title {
  grid-column: 3;
  grid-row: 1;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
}

.dday-row__date {
  grid-column: 3;
  grid-row: 2;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  font-size: 12px;
  line-height: 1.3;
  color: var(--dp-text-muted);
  font-variant-numeric: tabular-nums;
}

.dday-row__pin {
  display: flex;
  flex: 0 0 44px;
  align-items: center;
  justify-content: center;
  color: var(--dp-text-muted);
  cursor: pointer;
  transition: color 0.15s ease;
}

.dday-row__pin-icon {
  width: 17px;
  height: 17px;
}

.dday-row.is-pinned .dday-row__pin {
  color: var(--dp-warning);
}

.dday-row.is-pinned .dday-row__pin-icon {
  fill: currentColor;
}

.dday-section__add:focus-visible,
.dday-row__open:focus-visible,
.dday-row__pin:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: -2px;
  border-radius: 4px;
}

/* State colours (colour only, never geometry). */
.dday-row--urgent .dday-row__value {
  color: var(--dp-danger-hover);
}

.dday-row--soon .dday-row__value {
  color: var(--dp-warning-hover);
}

.dday-row--future .dday-row__value {
  color: var(--dp-text-primary);
}

.dday-row--past .dday-row__value {
  color: var(--dp-text-muted);
  font-weight: 600;
}

.dday-row--past .dday-row__title {
  color: var(--dp-text-secondary);
}

:global(.dark .dday-row--urgent .dday-row__value) {
  color: color-mix(in srgb, var(--dp-danger) 70%, white);
}

:global(.dark .dday-row--soon .dday-row__value) {
  color: color-mix(in srgb, var(--dp-warning) 85%, white);
}

@media (hover: hover) {
  .dday-row:hover {
    background: var(--dp-bg-tertiary);
  }

  .dday-row__pin:hover {
    color: var(--dp-warning);
  }
}

/* Desktop (>=640px): one line — D-N | lock | title | date | star, fixed 48px row. */
@media (min-width: 640px) {
  .dday-section {
    margin-top: 1.75rem;
  }

  .dday-section__title {
    font-size: 18px;
  }

  .dday-row {
    height: 48px;
  }

  .dday-row + .dday-row::before {
    left: 18px;
  }

  .dday-row.is-pinned::after {
    top: 10px;
    bottom: 10px;
  }

  .dday-row__open {
    grid-template-columns: 76px 16px minmax(0, 1fr) 132px;
    grid-template-rows: auto;
    column-gap: 12px;
    padding: 0 4px 0 18px;
  }

  .dday-row__value {
    grid-row: 1;
    font-size: 17px;
  }

  .dday-row__title {
    font-size: 15px;
  }

  .dday-row__date {
    grid-column: 4;
    grid-row: 1;
    text-align: right;
    font-size: 13px;
  }

  .dday-row__pin {
    flex-basis: 48px;
  }
}
</style>
