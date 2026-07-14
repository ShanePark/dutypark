<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { CalendarDays, CalendarPlus, ChevronRight, Info, Loader2, RotateCcw, X } from 'lucide-vue-next'
import { dutyApi } from '@/api/duty'
import { useSwal } from '@/composables/useSwal'
import type { DutyPatternDutyTypeDto, DutyPatternWeekday, MyDutyPatternDto } from '@/types'
import BaseModal from '@/components/common/BaseModal.vue'
import DutyTypePicker from '@/components/duty/DutyTypePicker.vue'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import {
  createDutyPatternFormState,
  DUTY_PATTERN_WEEKDAYS,
  toggleDutyPatternWeekday,
  type DutyPatternAssignment,
} from '@/utils/dutyPatternForm'

const { t } = useI18n()
const { confirm, showError, toastSuccess } = useSwal()

const weekdays = DUTY_PATTERN_WEEKDAYS

const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)
const response = ref<MyDutyPatternDto | null>(null)
const assignments = ref<DutyPatternAssignment[]>([])
const holidayOff = ref(true)

const pattern = computed(() => response.value?.pattern ?? null)
const hasPattern = computed(() => pattern.value != null)
const configurable = computed(() => response.value?.configurable === true)
const selectedWeekdays = computed(() => assignments.value.map((item) => item.weekday))
const visibleDutyTypeIds = computed(() => new Set(response.value?.dutyTypes.map((type) => type.id) ?? []))
const applicationPaused = computed(() => assignments.value.some(
  (assignment) => !visibleDutyTypeIds.value.has(assignment.dutyTypeId),
))
const patternPaused = computed(() => pattern.value?.days.some(
  (day) => !visibleDutyTypeIds.value.has(day.dutyType.id),
) ?? false)
const summaryDays = computed(() => DUTY_PATTERN_WEEKDAYS.map((weekday) => ({
  weekday,
  dutyType: pattern.value?.days.find((day) => day.weekday === weekday)?.dutyType ?? null,
})))
const unavailableReason = computed(() => {
  if (!response.value?.reason) return t('member.dutyPattern.unavailable.default')
  if (response.value.reason === 'TEAM_REQUIRED') {
    return t('member.dutyPattern.unavailable.team')
  }
  if (response.value.reason === 'DUTY_TYPE_REQUIRED') {
    return t('member.dutyPattern.unavailable.none')
  }
  return t('member.dutyPattern.unavailable.default')
})

function syncForm(data: MyDutyPatternDto) {
  const form = createDutyPatternFormState(data)
  response.value = data
  assignments.value = form.assignments
  holidayOff.value = form.holidayOff
}

async function loadPattern() {
  loading.value = true
  try {
    syncForm(await dutyApi.getMyPattern())
  } catch (error) {
    console.error('Failed to load duty pattern:', error)
    response.value = null
  } finally {
    loading.value = false
  }
}

function openModal() {
  if (!configurable.value || !response.value) return
  syncForm(response.value)
  showModal.value = true
}

function closeModal() {
  if (saving.value) return
  showModal.value = false
}

function toggleWeekday(day: DutyPatternWeekday) {
  if (!configurable.value || saving.value) return
  assignments.value = toggleDutyPatternWeekday(
    assignments.value,
    day,
    response.value?.dutyTypes[0]?.id ?? null,
  )
}

function dutyTypeOptions(assignment: DutyPatternAssignment): DutyPatternDutyTypeDto[] {
  const visible = response.value?.dutyTypes ?? []
  if (visible.some((type) => type.id === assignment.dutyTypeId)) return visible
  const hidden = response.value?.pattern?.days
    .find((day) => day.weekday === assignment.weekday)?.dutyType
  return hidden ? [hidden, ...visible] : visible
}

async function savePattern() {
  if (!configurable.value || assignments.value.length === 0) {
    showError(t('member.dutyPattern.validation.weekdayRequired'))
    return
  }
  if (applicationPaused.value) {
    showError(t('member.dutyPattern.validation.dutyTypeRequired'))
    return
  }
  if (!await confirm(
    t('member.dutyPattern.messages.saveConfirm'),
    hasPattern.value ? t('member.dutyPattern.actions.update') : t('member.dutyPattern.actions.save')
  )) return

  saving.value = true
  try {
    syncForm(await dutyApi.updateMyPattern({
      days: assignments.value,
      holidayOff: holidayOff.value,
    }))
    showModal.value = false
    toastSuccess(t('member.dutyPattern.messages.saveSuccess'))
  } catch (error) {
    console.error('Failed to save duty pattern:', error)
    try {
      syncForm(await dutyApi.getMyPattern())
    } catch (refreshError) {
      console.error('Failed to refresh duty pattern after save error:', refreshError)
    }
    showError(resolveApiErrorMessage(error, {
      fallbackKey: 'member.dutyPattern.messages.saveFailed',
    }, t))
  } finally {
    saving.value = false
  }
}

async function removePattern() {
  if (!hasPattern.value) return
  if (!await confirm(
    t('member.dutyPattern.messages.deleteConfirm'),
    t('member.dutyPattern.actions.delete')
  )) return

  saving.value = true
  try {
    await dutyApi.deleteMyPattern()
    if (response.value) {
      syncForm({ ...response.value, pattern: null })
    }
    showModal.value = false
    toastSuccess(t('member.dutyPattern.messages.deleteSuccess'))
  } catch (error) {
    console.error('Failed to delete duty pattern:', error)
    try {
      syncForm(await dutyApi.getMyPattern())
    } catch (refreshError) {
      console.error('Failed to refresh duty pattern after delete error:', refreshError)
    }
    showError(resolveApiErrorMessage(error, {
      fallbackKey: 'member.dutyPattern.messages.deleteFailed',
    }, t))
  } finally {
    saving.value = false
  }
}

onMounted(loadPattern)
</script>

<template>
  <section class="rounded-xl shadow-sm p-4 sm:p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
    <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
      <CalendarDays class="w-5 h-5 text-dp-text-secondary" />
      {{ t('member.dutyPattern.sectionTitle') }}
    </h2>

    <div v-if="loading" class="flex min-h-20 items-center justify-center">
      <Loader2 class="w-6 h-6 animate-spin text-dp-accent" />
    </div>

    <!-- Load failure -->
    <div v-else-if="!response" class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <p class="text-sm text-dp-text-secondary">{{ t('member.dutyPattern.messages.loadFailed') }}</p>
      <button
        type="button"
        class="min-h-11 px-4 py-2 rounded-lg font-medium cursor-pointer hover-lift bg-dp-bg-tertiary text-dp-text-primary"
        @click="loadPattern"
      >
        {{ t('common.actions.retry') }}
      </button>
    </div>

    <!-- Configured: compact summary, opens modal -->
    <button
      v-else-if="pattern"
      type="button"
      class="group w-full rounded-xl border p-3 sm:p-4 text-left cursor-pointer hover-lift bg-dp-bg-secondary border-dp-border-primary hover:border-dp-border-hover"
      @click="openModal"
    >
      <div class="grid grid-cols-7 gap-1.5 sm:gap-2">
        <div
          v-for="day in summaryDays"
          :key="day.weekday"
          class="flex min-w-0 flex-col items-center gap-1 rounded-lg border py-2"
          :class="day.dutyType ? 'bg-dp-bg-card border-dp-border-primary' : 'border-transparent'"
        >
          <span
            class="text-[11px] font-semibold"
            :class="day.dutyType ? 'text-dp-text-primary' : 'text-dp-text-muted'"
          >
            {{ t(`member.dutyPattern.weekdays.${day.weekday.toLowerCase()}`) }}
          </span>
          <span
            class="h-2.5 w-2.5 rounded-full border"
            :class="day.dutyType ? 'border-dp-border-secondary' : 'border-dashed border-dp-border-secondary'"
            :style="day.dutyType ? { backgroundColor: day.dutyType.color || 'var(--dp-duty-fallback)' } : undefined"
            aria-hidden="true"
          ></span>
          <span
            class="max-w-full truncate px-0.5 text-[10px]"
            :class="day.dutyType ? 'text-dp-text-secondary' : 'text-dp-text-muted'"
          >
            {{ day.dutyType ? day.dutyType.name : t('member.dutyPattern.summary.offDay') }}
          </span>
        </div>
      </div>

      <div class="mt-3 flex items-center justify-between gap-3">
        <div class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-xs text-dp-text-muted">
          <span
            v-if="pattern.holidayOff"
            class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium bg-dp-bg-tertiary text-dp-text-secondary"
          >
            {{ t('member.dutyPattern.summary.holidayOffBadge') }}
          </span>
          <span>{{ t('member.dutyPattern.effectiveFrom', { month: pattern.effectiveFrom }) }}</span>
        </div>
        <span class="flex shrink-0 items-center gap-0.5 text-sm font-medium text-dp-accent">
          {{ t('member.dutyPattern.summary.edit') }}
          <ChevronRight class="w-4 h-4 transition-transform group-hover:translate-x-0.5" />
        </span>
      </div>

      <p v-if="patternPaused" class="mt-2 flex items-center gap-1.5 text-xs text-dp-warning">
        <Info class="w-3.5 h-3.5 shrink-0" />
        {{ t('member.dutyPattern.paused.title') }}
      </p>
    </button>

    <!-- Not configured yet: call to action -->
    <button
      v-else-if="configurable"
      type="button"
      class="group w-full flex items-center gap-3 sm:gap-4 rounded-xl border-2 border-dashed p-4 text-left transition cursor-pointer border-dp-border-primary hover:border-dp-accent hover:bg-dp-accent-soft"
      @click="openModal"
    >
      <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-dp-accent-soft text-dp-accent">
        <CalendarPlus class="w-5 h-5" />
      </span>
      <span class="min-w-0 flex-1">
        <span class="block font-medium text-dp-text-primary">{{ t('member.dutyPattern.summary.setupTitle') }}</span>
        <span class="mt-0.5 block text-sm text-dp-text-secondary">{{ t('member.dutyPattern.summary.setupDescription') }}</span>
      </span>
      <span class="flex shrink-0 items-center gap-0.5 text-sm font-medium text-dp-accent">
        <span class="hidden sm:inline">{{ t('member.dutyPattern.summary.setupAction') }}</span>
        <ChevronRight class="w-4 h-4 transition-transform group-hover:translate-x-0.5" />
      </span>
    </button>

    <!-- Not configurable -->
    <div v-else class="rounded-lg border p-4 bg-dp-bg-secondary border-dp-border-primary">
      <p class="flex items-center gap-2 text-sm font-medium text-dp-text-primary">
        <Info class="w-4 h-4 shrink-0 text-dp-text-muted" />
        {{ t('member.dutyPattern.unavailable.title') }}
      </p>
      <p class="mt-1 text-sm text-dp-text-secondary">{{ unavailableReason }}</p>
    </div>

    <!-- Pattern settings modal -->
    <BaseModal
      :is-open="showModal"
      size="md"
      height="fit"
      rounded
      :panel-style="{ backgroundColor: 'var(--dp-bg-card)' }"
      @close="closeModal"
    >
      <div class="modal-header">
        <h2>{{ t('member.dutyPattern.modalTitle') }}</h2>
        <button
          type="button"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
          :disabled="saving"
          @click="closeModal"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="modal-body-form-lg">
        <p class="text-sm text-dp-text-secondary">
          {{ t('member.dutyPattern.description') }}
        </p>

        <div
          v-if="applicationPaused"
          class="rounded-lg border p-3 bg-dp-warning-soft border-dp-warning-border text-dp-warning"
        >
          <p class="text-sm font-medium">{{ t('member.dutyPattern.paused.title') }}</p>
          <p class="text-xs mt-1">{{ t('member.dutyPattern.paused.description') }}</p>
        </div>

        <fieldset :disabled="saving">
          <legend class="text-sm font-medium mb-2 text-dp-text-primary">
            {{ t('member.dutyPattern.weekdaysLabel') }}
          </legend>
          <div class="grid grid-cols-4 sm:grid-cols-7 gap-2">
            <button
              v-for="day in weekdays"
              :key="day"
              type="button"
              class="min-h-11 rounded-lg border text-sm font-semibold transition cursor-pointer disabled:cursor-not-allowed"
              :class="selectedWeekdays.includes(day)
                ? 'bg-dp-accent text-dp-text-on-dark border-dp-accent hover:bg-dp-accent-hover hover:border-dp-accent-hover'
                : 'bg-dp-bg-secondary text-dp-text-secondary border-dp-border-primary hover:bg-dp-bg-tertiary hover:border-dp-border-hover'"
              :aria-pressed="selectedWeekdays.includes(day)"
              @click="toggleWeekday(day)"
            >
              {{ t(`member.dutyPattern.weekdays.${day.toLowerCase()}`) }}
            </button>
          </div>
        </fieldset>

        <div v-if="assignments.length" class="space-y-2">
          <p class="text-sm font-medium text-dp-text-primary">
            {{ t('member.dutyPattern.dutyTypeByDay') }}
          </p>
          <div
            v-for="assignment in assignments"
            :key="assignment.weekday"
            class="grid grid-cols-[4rem_1fr] items-center gap-3"
          >
            <label
              :for="`duty-pattern-type-${assignment.weekday.toLowerCase()}`"
              class="text-sm font-semibold text-dp-text-secondary"
            >
              {{ t(`member.dutyPattern.weekdays.${assignment.weekday.toLowerCase()}`) }}
            </label>
            <DutyTypePicker
              v-model="assignment.dutyTypeId"
              :trigger-id="`duty-pattern-type-${assignment.weekday.toLowerCase()}`"
              :options="dutyTypeOptions(assignment)"
              :visible-option-ids="visibleDutyTypeIds"
              :label="t(`member.dutyPattern.weekdays.${assignment.weekday.toLowerCase()}`)"
              :hidden-label="t('team.manage.labels.hidden')"
              :close-label="t('common.actions.close')"
              :disabled="saving"
            />
          </div>
        </div>

        <label
          class="min-h-11 flex items-center justify-between gap-4 rounded-lg border px-3 py-2 cursor-pointer transition bg-dp-bg-secondary border-dp-border-primary hover:bg-dp-bg-tertiary hover:border-dp-border-hover"
        >
          <span>
            <span class="block font-medium text-dp-text-primary">{{ t('member.dutyPattern.holidayOff') }}</span>
            <span class="block text-xs mt-0.5 text-dp-text-muted">{{ t('member.dutyPattern.holidayOffHint') }}</span>
          </span>
          <input
            v-model="holidayOff"
            type="checkbox"
            class="h-5 w-5 accent-dp-accent"
            :disabled="saving"
          />
        </label>

        <p v-if="pattern" class="text-sm text-dp-text-muted">
          {{ t('member.dutyPattern.effectiveFrom', { month: pattern.effectiveFrom }) }}
        </p>

        <button
          v-if="hasPattern"
          type="button"
          :disabled="saving"
          class="w-full min-h-11 px-4 py-2 rounded-lg border font-medium flex items-center justify-center gap-2 transition cursor-pointer disabled:opacity-50 border-dp-danger-border text-dp-danger hover:bg-dp-danger-soft"
          @click="removePattern"
        >
          <RotateCcw class="w-4 h-4" />
          {{ t('member.dutyPattern.actions.delete') }}
        </button>
      </div>

      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button
          type="button"
          :disabled="saving || assignments.length === 0 || applicationPaused"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-dp-accent hover:bg-dp-accent-hover rounded-lg text-dp-text-on-dark font-medium transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 cursor-pointer"
          @click="savePattern"
        >
          <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
          {{ hasPattern ? t('member.dutyPattern.actions.update') : t('member.dutyPattern.actions.save') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer disabled:opacity-50"
          :style="{ backgroundColor: 'var(--dp-bg-hover)', color: 'var(--dp-text-primary)' }"
          @click="closeModal"
        >
          {{ t('common.actions.cancel') }}
        </button>
      </div>
    </BaseModal>
  </section>
</template>
