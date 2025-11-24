<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  Upload,
  FileText,
  Image,
  Download,
} from 'lucide-vue-next'

interface Attachment {
  id: string
  name: string
  originalFilename: string
  size: number
  contentType: string
  isImage: boolean
  hasThumbnail: boolean
  thumbnailUrl?: string
  downloadUrl: string
}

interface Todo {
  id: string
  title: string
  content: string
  status: 'ACTIVE' | 'COMPLETED'
  createdDate: string
  completedDate?: string
  attachments: Attachment[]
}

interface Props {
  isOpen: boolean
  todo: Todo | null
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'update', data: { id: string; title: string; content: string }): void
  (e: 'complete', id: string): void
  (e: 'reopen', id: string): void
  (e: 'delete', id: string): void
}>()

const isEditMode = ref(false)
const editTitle = ref('')
const editContent = ref('')
const editAttachments = ref<Attachment[]>([])

watch(
  () => props.isOpen,
  (open) => {
    if (open && props.todo) {
      isEditMode.value = false
      editTitle.value = props.todo.title
      editContent.value = props.todo.content
      editAttachments.value = [...props.todo.attachments]
    }
  }
)

const isActive = computed(() => props.todo?.status === 'ACTIVE')

function enterEditMode() {
  if (!props.todo) return
  isEditMode.value = true
  editTitle.value = props.todo.title
  editContent.value = props.todo.content
  editAttachments.value = [...props.todo.attachments]
}

function cancelEdit() {
  isEditMode.value = false
  if (props.todo) {
    editTitle.value = props.todo.title
    editContent.value = props.todo.content
    editAttachments.value = [...props.todo.attachments]
  }
}

function saveEdit() {
  if (!props.todo || !editTitle.value.trim()) return
  emit('update', {
    id: props.todo.id,
    title: editTitle.value.trim(),
    content: editContent.value.trim(),
  })
  isEditMode.value = false
}

function handleClose() {
  isEditMode.value = false
  emit('close')
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

function removeAttachment(id: string) {
  editAttachments.value = editAttachments.value.filter((a) => a.id !== id)
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && todo"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="handleClose"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-lg max-h-[90vh] overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <div class="flex items-center gap-2">
            <h2 class="text-lg font-bold">할 일 상세</h2>
            <span
              :class="[
                'px-2 py-0.5 text-xs rounded-full',
                isActive
                  ? 'bg-blue-100 text-blue-700'
                  : 'bg-gray-100 text-gray-600 line-through',
              ]"
            >
              {{ isActive ? '진행중' : '완료' }}
            </span>
          </div>
          <button @click="handleClose" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-4 overflow-y-auto max-h-[calc(90vh-200px)]">
          <!-- View Mode -->
          <template v-if="!isEditMode">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">제목</label>
                <p class="text-lg font-medium">{{ todo.title }}</p>
              </div>

              <div v-if="todo.content">
                <label class="block text-sm font-medium text-gray-500 mb-1">내용</label>
                <p class="text-gray-700 whitespace-pre-wrap">{{ todo.content }}</p>
              </div>

              <div class="text-sm text-gray-500">
                <p>등록: {{ todo.createdDate }}</p>
                <p v-if="todo.completedDate">완료: {{ todo.completedDate }}</p>
              </div>

              <!-- Attachments (View Mode) -->
              <div v-if="todo.attachments.length > 0">
                <label class="block text-sm font-medium text-gray-500 mb-2">첨부파일</label>
                <div class="grid grid-cols-2 gap-2">
                  <div
                    v-for="attachment in todo.attachments"
                    :key="attachment.id"
                    class="border border-gray-200 rounded-lg overflow-hidden"
                  >
                    <div
                      v-if="attachment.hasThumbnail"
                      class="aspect-square bg-gray-100 flex items-center justify-center"
                    >
                      <img
                        :src="attachment.thumbnailUrl"
                        :alt="attachment.originalFilename"
                        class="w-full h-full object-cover"
                      />
                    </div>
                    <div
                      v-else
                      class="aspect-square bg-gray-50 flex items-center justify-center"
                    >
                      <FileText class="w-12 h-12 text-gray-300" />
                    </div>
                    <div class="p-2">
                      <p class="text-sm truncate" :title="attachment.originalFilename">
                        {{ attachment.originalFilename }}
                      </p>
                      <div class="flex items-center justify-between mt-1">
                        <span class="text-xs text-gray-500">{{
                          formatBytes(attachment.size)
                        }}</span>
                        <a
                          :href="attachment.downloadUrl"
                          download
                          class="text-blue-600 hover:text-blue-700"
                        >
                          <Download class="w-4 h-4" />
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- Edit Mode -->
          <template v-else>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  제목 <span class="text-red-500">*</span>
                </label>
                <input
                  v-model="editTitle"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">내용</label>
                <textarea
                  v-model="editContent"
                  rows="4"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                ></textarea>
              </div>

              <!-- Attachments (Edit Mode) -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">첨부파일</label>
                <label
                  class="flex items-center justify-center gap-2 w-full h-16 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition"
                >
                  <Upload class="w-5 h-5 text-gray-400" />
                  <span class="text-sm text-gray-500">파일 추가</span>
                  <input type="file" multiple class="hidden" />
                </label>

                <div v-if="editAttachments.length > 0" class="mt-2 space-y-2">
                  <div
                    v-for="attachment in editAttachments"
                    :key="attachment.id"
                    class="flex items-center gap-3 p-2 bg-gray-50 rounded-lg"
                  >
                    <div class="flex-shrink-0">
                      <Image v-if="attachment.isImage" class="w-6 h-6 text-gray-400" />
                      <FileText v-else class="w-6 h-6 text-gray-400" />
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm truncate">{{ attachment.originalFilename }}</p>
                      <p class="text-xs text-gray-500">{{ formatBytes(attachment.size) }}</p>
                    </div>
                    <button
                      @click="removeAttachment(attachment.id)"
                      class="p-1 text-gray-400 hover:text-red-600"
                    >
                      <Trash2 class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </template>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-200">
          <template v-if="!isEditMode">
            <div class="flex items-center justify-between">
              <div class="flex gap-2">
                <button
                  v-if="isActive"
                  @click="emit('complete', todo.id)"
                  class="flex items-center gap-1 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                >
                  <Check class="w-4 h-4" />
                  완료
                </button>
                <button
                  v-else
                  @click="emit('reopen', todo.id)"
                  class="flex items-center gap-1 px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                >
                  <RotateCcw class="w-4 h-4" />
                  재오픈
                </button>
              </div>
              <div class="flex gap-2">
                <button
                  @click="enterEditMode"
                  class="flex items-center gap-1 px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
                >
                  <Pencil class="w-4 h-4" />
                  수정
                </button>
                <button
                  @click="emit('delete', todo.id)"
                  class="flex items-center gap-1 px-3 py-2 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition"
                >
                  <Trash2 class="w-4 h-4" />
                  삭제
                </button>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="flex justify-end gap-2">
              <button
                @click="cancelEdit"
                class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
              >
                취소
              </button>
              <button
                @click="saveEdit"
                :disabled="!editTitle.trim()"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50"
              >
                저장
              </button>
            </div>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>
