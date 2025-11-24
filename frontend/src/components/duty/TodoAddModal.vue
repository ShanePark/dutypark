<script setup lang="ts">
import { ref, watch } from 'vue'
import { X, Upload, FileText, Image, Trash2 } from 'lucide-vue-next'

interface Attachment {
  id: string
  name: string
  size: number
  isImage: boolean
  previewUrl?: string
  progress?: number
}

interface Props {
  isOpen: boolean
}

defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', data: { title: string; content: string }): void
}>()

const title = ref('')
const content = ref('')
const attachments = ref<Attachment[]>([])

watch(
  () => title.value,
  () => {
    // Reset when modal opens fresh
  }
)

function handleClose() {
  title.value = ''
  content.value = ''
  attachments.value = []
  emit('close')
}

function handleSave() {
  if (!title.value.trim()) {
    return
  }
  emit('save', {
    title: title.value.trim(),
    content: content.value.trim(),
  })
  handleClose()
}

function removeAttachment(id: string) {
  attachments.value = attachments.value.filter((a) => a.id !== id)
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="handleClose"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md max-h-[90vh] overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 class="text-lg font-bold">할 일 추가</h2>
          <button @click="handleClose" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-4 overflow-y-auto max-h-[calc(90vh-130px)]">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                제목 <span class="text-red-500">*</span>
              </label>
              <input
                v-model="title"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="할 일 제목을 입력하세요"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">내용</label>
              <textarea
                v-model="content"
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="상세 내용을 입력하세요 (선택사항)"
              ></textarea>
            </div>

            <!-- Attachment Upload -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">첨부파일</label>
              <label
                class="flex items-center justify-center gap-2 w-full h-20 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition"
              >
                <Upload class="w-5 h-5 text-gray-400" />
                <span class="text-sm text-gray-500">파일을 드래그하거나 클릭하여 업로드</span>
                <input type="file" multiple class="hidden" />
              </label>
            </div>

            <!-- Uploaded Attachments -->
            <div v-if="attachments.length > 0" class="space-y-2">
              <div
                v-for="attachment in attachments"
                :key="attachment.id"
                class="flex items-center gap-3 p-2 bg-gray-50 rounded-lg"
              >
                <div class="flex-shrink-0">
                  <Image v-if="attachment.isImage" class="w-8 h-8 text-gray-400" />
                  <FileText v-else class="w-8 h-8 text-gray-400" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-700 truncate">{{ attachment.name }}</p>
                  <p class="text-xs text-gray-500">{{ formatBytes(attachment.size) }}</p>
                  <div
                    v-if="attachment.progress !== undefined && attachment.progress < 100"
                    class="w-full bg-gray-200 rounded-full h-1.5 mt-1"
                  >
                    <div
                      class="bg-blue-600 h-1.5 rounded-full transition-all"
                      :style="{ width: `${attachment.progress}%` }"
                    ></div>
                  </div>
                </div>
                <button
                  @click="removeAttachment(attachment.id)"
                  class="p-1 text-gray-400 hover:text-red-600 transition"
                >
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
          <button
            @click="handleClose"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
          >
            취소
          </button>
          <button
            @click="handleSave"
            :disabled="!title.trim()"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            저장
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
