<script lang="ts">
import {
  defaultEndDateTime,
  defaultStartTime,
  extractDate,
  extractEndTime,
  extractTime,
  isRangeInvalid,
  joinDateTime,
} from '@/utils/scheduleDateTime'

/**
 * The end date control is bounded at the start, but a bound on it cannot stop the *start* from
 * moving past it, which edit mode allows — so the end follows the start rather than being left in
 * a range the modal would only reject on save. The date rises to the start's day, and an end time
 * the start has caught up with is re-proposed by the same rule that first offered one. An end
 * without a time needs no bump: it means that whole day, and `effectiveEndDateTime` already folds
 * a same-day one onto the start.
 *
 * The end time is passed in rather than read back out of the end, because "no end time" is stored
 * as an end equal to the start: once the start has moved, the old start would read back as a real
 * end time. Mirrors `ScheduleEditorTimePolicy.endFollowingStart` in the iOS editor.
 */
export function endFollowingStart(
  startDateTime: string,
  endDate: string,
  endTime: string | null,
): string {
  const startDate = extractDate(startDateTime)
  const date = endDate < startDate ? startDate : endDate
  if (endTime === null) return joinDateTime(date, null)
  const anchored = joinDateTime(date, endTime)
  return anchored > startDateTime ? anchored : defaultEndDateTime(startDateTime, date)
}
</script>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { Check, Clock, X } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import DatePickerField from '@/components/common/DatePickerField.vue'
import type { NormalizedAttachment, TaggableFriend } from '@/types'
import type { CalendarVisibility } from '@/utils/visibility'

interface SelectedTagSummary {
  id: number
  name: string
}

interface ScheduleFormData {
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: CalendarVisibility
  tagFriendIds: number[]
}

interface VisibilityOption {
  value: CalendarVisibility
  label: string
  icon: any
  color: string
}

const props = defineProps<{
  form: ScheduleFormData
  editAttachments: NormalizedAttachment[]
  visibilityOptions: VisibilityOption[]
  isEditMode: boolean
  friends: TaggableFriend[]
  canTagFriends: boolean
  selectedTagSummaries: SelectedTagSummary[]
}>()

/**
 * "No end time" is stored as an end equal to the start, so every change to the start has to
 * renormalize it — otherwise moving the start would resurrect the old start as an end time.
 * Both halves of the end are therefore read through the *old* start, before it moves.
 */
function setStart(date: string, time: string | null) {
  // Midnight is how "no time" is stored, so a start that loses its time takes the end time with
  // it: an end time left behind on its own would read back against a real 00:00 start.
  const nextEndTime = time === null ? null : endTime.value
  const currentEndDate = endDate.value
  props.form.startDateTime = joinDateTime(date, time)
  props.form.endDateTime = endFollowingStart(props.form.startDateTime, currentEndDate, nextEndTime)
}

const startDate = computed({
  get: () => extractDate(props.form.startDateTime),
  set: (date: string) => setStart(date, startTime.value),
})

const endDate = computed({
  get: () => extractDate(props.form.endDateTime),
  // The picker cannot offer a day before the start, but it does offer the start's own day, on
  // which the end's existing clock reading may no longer fall after the start.
  set: (date: string) => {
    props.form.endDateTime = endFollowingStart(props.form.startDateTime, date, endTime.value)
  },
})

/**
 * The time is optional: until it is added the field stays empty instead of showing a
 * midnight the user would feel obliged to correct.
 */
const startTime = computed({
  get: () => extractTime(props.form.startDateTime),
  set: (time: string | null) => setStart(startDate.value, time),
})

const endTime = computed({
  get: () => extractEndTime(props.form.endDateTime, props.form.startDateTime),
  set: (time: string | null) => {
    props.form.endDateTime = joinDateTime(endDate.value, time)
  },
})

function addStartTime() {
  startTime.value = defaultStartTime(new Date())
}

function addEndTime() {
  // The default can have to move the end date itself, so it sets the whole end.
  props.form.endDateTime = defaultEndDateTime(props.form.startDateTime, endDate.value)
}

const emit = defineEmits<{
  (e: 'upload-start'): void
  (e: 'upload-complete'): void
  (e: 'error', message: string): void
}>()

const { t } = useI18n()

const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)

const isTitleMissing = computed(() => !props.form.content.trim())
const isTimeRangeInvalid = computed(() =>
  isRangeInvalid(props.form.startDateTime, props.form.endDateTime)
)

function getSessionId() {
  return fileUploaderRef.value?.getSessionId() || null
}

function getAttachments() {
  return fileUploaderRef.value?.getAttachments() || []
}

function cleanup() {
  fileUploaderRef.value?.cleanup()
}

function isUploading() {
  return fileUploaderRef.value?.isUploading() ?? false
}

defineExpose({
  getSessionId,
  getAttachments,
  cleanup,
  isUploading,
})
</script>

<template>
  <div class="schedule-form">
    <div class="schedule-form__row">
      <label class="schedule-form__label schedule-form__label--required text-sm text-dp-text-secondary"
        >{{ t('duty.schedule.fields.title') }}<span class="schedule-form__required text-dp-danger">*</span></label
      >
      <div class="schedule-form__control relative">
        <input
          v-model="form.content"
          type="text"
          maxlength="50"
          class="schedule-form__input schedule-form__input--with-counter w-full px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
          :placeholder="t('duty.schedule.placeholders.title')"
          :aria-invalid="isTitleMissing"
        />
        <div class="schedule-form__counter pointer-events-none absolute right-2 top-1/2 -translate-y-1/2">
          <CharacterCounter :current="form.content.length" :max="50" />
        </div>
      </div>
    </div>

    <!-- Start and end share one grid so their date and time controls line up in columns. -->
    <div class="schedule-form__datetime">
      <label class="schedule-form__label text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.startDateTime') }}</label>
      <!-- A new schedule belongs to the day that opened the modal, so its start date is fixed.
           It stays the same date control, only read-only, so both rows render alike. -->
      <DatePickerField
        v-if="!isEditMode"
        :model-value="startDate"
        readonly
        :aria-label="t('duty.schedule.fields.startDateTime')"
        class="schedule-form__date"
      />
      <DatePickerField
        v-else
        v-model="startDate"
        :invalid="isTimeRangeInvalid"
        :aria-label="t('duty.schedule.fields.startDateTime')"
        class="schedule-form__date"
      />
      <div class="schedule-form__time-slot">
        <template v-if="startTime !== null">
          <input
            v-model="startTime"
            type="time"
            :aria-label="t('duty.schedule.fields.startDateTime')"
            class="schedule-form__input schedule-form__time px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
            :class="{ 'schedule-form__input--invalid': isTimeRangeInvalid }"
            :aria-invalid="isTimeRangeInvalid"
          />
          <button
            type="button"
            class="schedule-form__time-remove"
            :aria-label="t('duty.schedule.time.remove')"
            @click="startTime = null"
          >
            <X class="w-4 h-4" />
          </button>
        </template>
        <button v-else type="button" class="schedule-form__time-add" @click="addStartTime">
          <Clock class="w-3.5 h-3.5" />
          <span>{{ t('duty.schedule.time.add') }}</span>
        </button>
      </div>

      <label class="schedule-form__label text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.endDateTime') }}</label>
      <!-- The end is picked as a range anchored at the start: the span paints as one block and
           every day before the start is unreachable, so an end earlier than the start can no
           longer be chosen and then flagged. `min` says the same thing the anchor implies, at the
           one place a reader looks for the bound. -->
      <DatePickerField
        v-model="endDate"
        mode="range"
        :range-start="startDate"
        :min="startDate"
        :invalid="isTimeRangeInvalid"
        :aria-label="t('duty.schedule.fields.endDateTime')"
        class="schedule-form__date"
      />
      <div class="schedule-form__time-slot">
        <template v-if="endTime !== null">
          <input
            v-model="endTime"
            type="time"
            :aria-label="t('duty.schedule.fields.endDateTime')"
            class="schedule-form__input schedule-form__time px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
            :class="{ 'schedule-form__input--invalid': isTimeRangeInvalid }"
            :aria-invalid="isTimeRangeInvalid"
          />
          <button
            type="button"
            class="schedule-form__time-remove"
            :aria-label="t('duty.schedule.time.remove')"
            @click="endTime = null"
          >
            <X class="w-4 h-4" />
          </button>
        </template>
        <!-- The end time depends on the start, so until a start time exists the end offers no
             button at all: an always-visible control the user cannot use reads as broken. -->
        <button
          v-else-if="startTime !== null"
          type="button"
          class="schedule-form__time-add"
          @click="addEndTime"
        >
          <Clock class="w-3.5 h-3.5" />
          <span>{{ t('duty.schedule.time.add') }}</span>
        </button>
      </div>
    </div>

    <div class="schedule-form__row schedule-form__row--top">
      <label class="schedule-form__label schedule-form__label--top text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.description') }}</label>
      <textarea
        v-model="form.description"
        rows="2"
        class="schedule-form__input schedule-form__textarea schedule-form__control w-full px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
        :placeholder="t('duty.schedule.placeholders.description')"
      ></textarea>
    </div>

    <div class="schedule-form__row schedule-form__row--top">
      <label class="schedule-form__label schedule-form__label--top text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.visibility') }}</label>
      <div class="schedule-form__control grid grid-cols-4 gap-1 sm:gap-2">
        <button
          v-for="option in visibilityOptions"
          :key="option.value"
          type="button"
          @click="form.visibility = option.value"
          class="visibility-card relative flex min-h-11 flex-col items-center justify-center gap-1 px-1 py-2 sm:min-h-12 sm:gap-1.5 sm:px-2 sm:py-2.5 rounded-lg border-2 transition-all duration-150 cursor-pointer text-center"
          :class="{
            'visibility-card-selected': form.visibility === option.value,
            'visibility-card-unselected': form.visibility !== option.value
          }"
        >
          <div
            v-if="form.visibility === option.value"
            class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-dp-accent rounded-full flex items-center justify-center shadow-sm"
          >
            <Check class="w-3 h-3 text-dp-text-on-dark" />
          </div>
          <div class="flex-shrink-0 w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center" :class="option.color">
            <component
              :is="option.icon"
              class="w-3 h-3 sm:w-4 sm:h-4 text-dp-text-on-dark"
            />
          </div>
          <div class="min-w-0 w-full">
            <div
              class="font-medium text-[11px] sm:text-xs md:text-sm leading-tight whitespace-nowrap"
              :class="{
                'text-dp-accent-hover dark:text-dp-accent-light': form.visibility === option.value
              }"
              :style="form.visibility !== option.value ? { color: 'var(--dp-text-primary)' } : undefined"
            >
              {{ option.label }}
            </div>
          </div>
        </button>
      </div>
    </div>

    <!-- Attachment Upload Area -->
    <div class="schedule-form__row schedule-form__row--top">
      <label class="schedule-form__label schedule-form__label--top text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.attachments') }}</label>
      <FileUploader
        class="schedule-form__file-uploader schedule-form__control"
        ref="fileUploaderRef"
        context-type="SCHEDULE"
        :existing-attachments="editAttachments"
        @upload-start="emit('upload-start')"
        @upload-complete="emit('upload-complete')"
        @error="emit('error', $event)"
      />
    </div>

    <div v-if="canTagFriends" class="schedule-form__row schedule-form__row--top">
      <label class="schedule-form__label schedule-form__label--top text-sm text-dp-text-secondary">{{ t('duty.schedule.fields.friendTag') }}</label>
      <div class="schedule-form__control">
        <FriendTagSelector
          v-model="form.tagFriendIds"
          :friends="friends"
          :selected-summaries="selectedTagSummaries"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
/* The whole form is one column grid: every row is laid out from the same label width, column gap
   and row gap tokens, so every control starts at one x and ends at one x. */
.schedule-form {
  --schedule-form-label-width: 5.5rem;
  --schedule-form-label-line: 1.25rem;
  --schedule-form-column-gap: 0.5rem;
  --schedule-form-row-gap: 0.75rem;
  --schedule-form-control-height: 2.625rem;
  --schedule-form-control-pad-y: 0.5rem;
  --schedule-form-control-line: 1.5rem;
  --schedule-form-time-clear-width: 1.75rem;
  display: grid;
  gap: var(--schedule-form-row-gap);
}

/* Korean labels are all two-character words ("공개 범위", "첨부파일"), so a two-character column
   wraps the four-character ones into an even block and every row's control starts at the same x —
   room the narrow screens need. Latin labels have no such break point inside a word, so they keep
   a column wide enough for the longest of them. */
.schedule-form:lang(ko) {
  --schedule-form-label-width: 2rem;
}

.schedule-form__row {
  display: grid;
  grid-template-columns: var(--schedule-form-label-width) minmax(0, 1fr);
  align-items: center;
  column-gap: var(--schedule-form-column-gap);
}

/* A control taller than one line keeps its label on the first line instead of centring it. */
.schedule-form__row--top {
  align-items: start;
}

.schedule-form__label {
  width: var(--schedule-form-label-width);
  line-height: var(--schedule-form-label-line);
}

/* The label's first line has to land on the control's first line: the control's border and padding
   push its text down, and the two line boxes differ in height. */
.schedule-form__label--top {
  padding-top: calc(
    var(--schedule-form-control-pad-y) + 1px +
      (var(--schedule-form-control-line) - var(--schedule-form-label-line)) / 2
  );
}

/* The Korean label column is exactly two Hangul characters wide, so a required marker sharing the
   label's box would wrap onto a second line. The marker hangs into the column gap instead of
   widening the column every control is aligned to, and takes a margin rather than a space so it
   stays clear of the control beside it. */
.schedule-form__label--required {
  white-space: nowrap;
}

.schedule-form__required {
  margin-left: 0.125rem;
}

/* A grid item's automatic minimum size is its content, so without this a long value would push the
   control column past the row's right edge. */
.schedule-form__control {
  min-width: 0;
}

/* Label, date, time — the date and the time split what is left of the row evenly, so the two
   rows read as one aligned grid instead of two differently sized pairs. */
.schedule-form__datetime {
  display: grid;
  grid-template-columns: var(--schedule-form-label-width) minmax(0, 1fr) minmax(0, 1fr);
  align-items: center;
  column-gap: var(--schedule-form-column-gap);
  row-gap: var(--schedule-form-row-gap);
}

/* The clear button keeps its own column whether or not a time is set, so adding or removing a time
   never resizes the date and time halves, and the row ends at the same x either way. */
.schedule-form__time-slot {
  display: grid;
  grid-template-columns: minmax(0, 1fr) var(--schedule-form-time-clear-width);
  align-items: center;
  column-gap: 0.25rem;
  min-width: 0;
}

/* The time control and the chip that creates it fill the same box. */
.schedule-form__time,
.schedule-form__time-add {
  grid-column: 1;
  width: 100%;
}

/* One height for every single-line control, so a row is the same height whichever controls it
   holds and the rows keep an even rhythm. The date control is a component with more than one root
   node, which never inherits this file's scope id, so its rules have to reach it through :deep(). */
input.schedule-form__input,
.schedule-form__time-add,
:deep(.schedule-form__date) {
  min-height: var(--schedule-form-control-height);
}

.schedule-form__time-add {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  padding: 0.375rem 0.625rem;
  border-radius: 0.5rem;
  background-color: var(--dp-accent-bg);
  color: var(--dp-accent);
  font-size: 0.8125rem;
  white-space: nowrap;
  cursor: pointer;
}

.schedule-form__time-remove {
  grid-column: 2;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--schedule-form-time-clear-width);
  height: var(--schedule-form-time-clear-width);
  border-radius: 9999px;
  color: var(--dp-text-muted);
  cursor: pointer;
}

.schedule-form__time-remove:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.visibility-card-selected {
  border-color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
  box-shadow: 0 0 0 1px var(--dp-accent), 0 2px 8px var(--dp-accent-ring);
}

.visibility-card-unselected {
  border-color: var(--dp-border-primary);
  background-color: var(--dp-bg-card);
  opacity: 0.72;
}

.visibility-card-unselected:hover {
  border-color: var(--dp-accent-border);
  background-color: var(--dp-bg-secondary);
  opacity: 0.92;
}

.schedule-form__input--invalid {
  border-color: var(--dp-warning);
}

@media (max-width: 639px) {
  .schedule-form {
    --schedule-form-label-line: 1.15rem;
    --schedule-form-row-gap: 0.375rem;
    --schedule-form-control-height: 2.75rem;
    --schedule-form-control-pad-y: 0.625rem;
    --schedule-form-control-line: 1.40625rem;
    --schedule-form-time-clear-width: 1.5rem;
  }

  .schedule-form__label {
    font-size: 0.8125rem;
  }

  /* A two-character Korean label leaves just enough of a phone row for both native controls once
     the gap after the label tightens, and the last of the width comes from the time field's picker
     button: tapping the field opens the picker anyway, and the clear button beside it still marks
     the control. The gap tightens through the token so every row moves together — narrowing the
     date/time grid alone would start its controls 4px left of every other row. */
  .schedule-form:lang(ko) {
    --schedule-form-column-gap: 0.25rem;
  }

  .schedule-form:lang(ko) .schedule-form__time::-webkit-calendar-picker-indicator {
    display: none;
  }

  /* A Latin label has no break point inside a word, so its column leaves too little of the row for
     two native controls: there the time drops under the date and keeps its own width. */
  .schedule-form:not(:lang(ko)) .schedule-form__datetime {
    grid-template-columns: var(--schedule-form-label-width) minmax(0, 1fr);
  }

  .schedule-form:not(:lang(ko)) .schedule-form__datetime > .schedule-form__label {
    grid-column: 1;
  }

  .schedule-form:not(:lang(ko)) :deep(.schedule-form__date),
  .schedule-form:not(:lang(ko)) .schedule-form__time-slot {
    grid-column: 2;
  }

  .schedule-form__time-add {
    font-size: 0.75rem;
    padding-left: 0.375rem;
    padding-right: 0.375rem;
  }

  .schedule-form__input {
    padding-top: var(--schedule-form-control-pad-y);
    padding-bottom: var(--schedule-form-control-pad-y);
    font-size: 0.9375rem;
  }

  :deep(.schedule-form__date),
  .schedule-form__time {
    font-size: 0.8125rem;
  }

  .schedule-form__input--with-counter {
    padding-right: 4.75rem;
  }

  .schedule-form__textarea {
    min-height: 4.5rem;
  }

  .visibility-card {
    min-height: 3.75rem;
    gap: 0.375rem;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .visibility-card :deep(svg) {
    width: 0.875rem;
    height: 0.875rem;
  }

  .schedule-form__file-uploader :deep(.file-uploader) {
    gap: 0.5rem;
  }

  .schedule-form__file-uploader :deep(.drop-zone) {
    padding: 0.5rem 0.875rem;
  }

  .schedule-form__file-uploader :deep(.attachment-list) {
    gap: 0.375rem;
  }

  .schedule-form__file-uploader :deep(.attachment-item) {
    padding: 0.375rem 0.5rem;
  }
}

.schedule-form__input--with-counter {
  padding-right: 5.25rem;
}

.schedule-form__counter {
  padding-left: 0.375rem;
  background-color: var(--dp-bg-input);
  line-height: 1;
}
</style>
