<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { CalendarDays, Loader2, RotateCcw } from 'lucide-vue-next'
import { dutyApi } from '@/api/duty'
import { useSwal } from '@/composables/useSwal'
import type { DutyPatternDutyTypeDto, DutyPatternWeekday, MyDutyPatternDto } from '@/types'
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
const response = ref<MyDutyPatternDto | null>(null)
const assignments = ref<DutyPatternAssignment[]>([])
const holidayOff = ref(true)

const hasPattern = computed(() => response.value?.pattern != null)
const configurable = computed(() => response.value?.configurable === true)
const selectedWeekdays = computed(() => assignments.value.map((item) => item.weekday))
const visibleDutyTypeIds = computed(() => new Set(response.value?.dutyTypes.map((type) => type.id) ?? []))
const applicationPaused = computed(() => assignments.value.some(
  (assignment) => !visibleDutyTypeIds.value.has(assignment.dutyTypeId),
))
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
    showError(t('member.dutyPattern.messages.loadFailed'))
  } finally {
    loading.value = false
  }
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
    <h2 class="text-lg font-semibold mb-2 flex items-center gap-2 text-dp-text-primary">
      <CalendarDays class="w-5 h-5 text-dp-text-secondary" />
      {{ t('member.dutyPattern.sectionTitle') }}
    </h2>
    <p class="text-sm mb-4 text-dp-text-secondary">
      {{ t('member.dutyPattern.description') }}
    </p>

    <div v-if="loading" class="flex min-h-28 items-center justify-center">
      <Loader2 class="w-6 h-6 animate-spin text-dp-accent" />
    </div>

    <template v-else-if="response">
      <div
        v-if="!configurable || applicationPaused"
        class="rounded-lg border p-4 bg-dp-warning-soft border-dp-warning-border text-dp-warning"
      >
        <p class="font-medium">
          {{ t(applicationPaused ? 'member.dutyPattern.paused.title' : 'member.dutyPattern.unavailable.title') }}
        </p>
        <p class="text-sm mt-1">
          {{ applicationPaused ? t('member.dutyPattern.paused.description') : unavailableReason }}
        </p>
      </div>

      <div class="space-y-5" :class="{ 'opacity-60': !configurable }">
        <fieldset :disabled="!configurable || saving">
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
                ? 'bg-dp-accent text-dp-text-on-dark border-dp-accent'
                : 'bg-dp-bg-secondary text-dp-text-secondary border-dp-border-primary hover:bg-dp-bg-hover'"
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
              :disabled="!configurable || saving"
            />
          </div>
        </div>

        <label
          class="min-h-11 flex items-center justify-between gap-4 rounded-lg border px-3 py-2 bg-dp-bg-secondary border-dp-border-primary"
          :class="configurable ? 'cursor-pointer' : 'cursor-not-allowed'"
        >
          <span>
            <span class="block font-medium text-dp-text-primary">{{ t('member.dutyPattern.holidayOff') }}</span>
            <span class="block text-xs mt-0.5 text-dp-text-muted">{{ t('member.dutyPattern.holidayOffHint') }}</span>
          </span>
          <input
            v-model="holidayOff"
            type="checkbox"
            class="h-5 w-5 accent-dp-accent"
            :disabled="!configurable || saving"
          />
        </label>

        <p v-if="response.pattern" class="text-sm text-dp-text-muted">
          {{ t('member.dutyPattern.effectiveFrom', { month: response.pattern.effectiveFrom }) }}
        </p>

        <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-2">
          <button
            v-if="hasPattern"
            type="button"
            :disabled="saving"
            class="min-h-11 px-4 py-2 rounded-lg border font-medium flex items-center justify-center gap-2 transition cursor-pointer disabled:opacity-50 border-dp-danger-border text-dp-danger hover:bg-dp-danger-soft"
            @click="removePattern"
          >
            <RotateCcw class="w-4 h-4" />
            {{ t('member.dutyPattern.actions.delete') }}
          </button>
          <button
            type="button"
            :disabled="!configurable || saving || assignments.length === 0 || applicationPaused"
            class="min-h-11 px-5 py-2 rounded-lg font-medium flex items-center justify-center gap-2 transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-accent text-dp-text-on-dark hover:bg-dp-accent-hover"
            @click="savePattern"
          >
            <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
            {{ hasPattern ? t('member.dutyPattern.actions.update') : t('member.dutyPattern.actions.save') }}
          </button>
        </div>
      </div>
    </template>
  </section>
</template>
