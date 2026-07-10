<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { CalendarDays, Loader2, RotateCcw } from 'lucide-vue-next'
import { dutyApi } from '@/api/duty'
import { useSwal } from '@/composables/useSwal'
import type { DutyPatternWeekday, MyDutyPatternDto } from '@/types'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'

const { t } = useI18n()
const { confirm, showError, toastSuccess } = useSwal()

const weekdays: DutyPatternWeekday[] = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
]
const defaultWeekdays: DutyPatternWeekday[] = weekdays.slice(0, 5)

const loading = ref(true)
const saving = ref(false)
const response = ref<MyDutyPatternDto | null>(null)
const selectedWeekdays = ref<DutyPatternWeekday[]>([...defaultWeekdays])
const holidayOff = ref(true)

const hasPattern = computed(() => response.value?.pattern != null)
const configurable = computed(() => response.value?.configurable === true)
const applicationPaused = computed(() => hasPattern.value && !configurable.value)
const unavailableReason = computed(() => {
  if (!response.value?.reason) return t('member.dutyPattern.unavailable.default')
  if (response.value.reason === 'TEAM_REQUIRED') {
    return t('member.dutyPattern.unavailable.team')
  }
  if (response.value.reason === 'DUTY_TYPE_REQUIRED') {
    return t('member.dutyPattern.unavailable.none')
  }
  if (response.value.reason === 'SINGLE_DUTY_TYPE_REQUIRED') {
    return t('member.dutyPattern.unavailable.multiple')
  }
  return t('member.dutyPattern.unavailable.default')
})

function syncForm(data: MyDutyPatternDto) {
  response.value = data
  selectedWeekdays.value = data.pattern
    ? [...data.pattern.weekdays]
    : [...defaultWeekdays]
  holidayOff.value = data.pattern?.holidayOff ?? true
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
  selectedWeekdays.value = selectedWeekdays.value.includes(day)
    ? selectedWeekdays.value.filter((item) => item !== day)
    : weekdays.filter((item) => item === day || selectedWeekdays.value.includes(item))
}

async function savePattern() {
  if (!configurable.value || selectedWeekdays.value.length === 0) {
    showError(t('member.dutyPattern.validation.weekdayRequired'))
    return
  }
  if (!await confirm(
    t('member.dutyPattern.messages.saveConfirm'),
    hasPattern.value ? t('member.dutyPattern.actions.update') : t('member.dutyPattern.actions.save')
  )) return

  saving.value = true
  try {
    syncForm(await dutyApi.updateMyPattern({
      weekdays: selectedWeekdays.value,
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
        v-if="!configurable"
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
        <div>
          <p class="text-sm font-medium mb-2 text-dp-text-primary">
            {{ t('member.dutyPattern.dutyType') }}
          </p>
          <div
            v-if="response.dutyType"
            class="min-h-11 flex items-center gap-2 px-3 py-2 rounded-lg border bg-dp-bg-secondary border-dp-border-primary text-dp-text-primary"
          >
            <span
              class="w-4 h-4 rounded-full border border-dp-border-secondary"
              :style="{ backgroundColor: response.dutyType.color || 'var(--dp-duty-fallback)' }"
            ></span>
            <span class="font-medium">{{ response.dutyType.name }}</span>
            <span class="ml-auto text-xs text-dp-text-muted">{{ t('member.dutyPattern.automatic') }}</span>
          </div>
          <p v-else class="text-sm text-dp-text-muted">{{ t('member.dutyPattern.noDutyType') }}</p>
        </div>

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
            :disabled="!configurable || saving || selectedWeekdays.length === 0"
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
