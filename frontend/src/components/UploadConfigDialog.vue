<template>
  <t-dialog
    :visible="props.visible"
    :title="title"
    :width="720"
    :footer="false"
    :close-on-esc-keydown="false"
    :close-on-overlay-click="false"
    @close="handleClose"
  >
    <div class="upload-config-dialog">
      <!-- File List Section -->
      <div v-if="files.length > 0" class="file-list-section">
        <div class="section-title">{{ $t('uploadConfig.files') }}</div>
        <t-ul>
          <t-li v-for="(file, index) in displayFiles" :key="index">
            <span class="file-name">{{ file.name }}</span>
            <span class="file-size" v-if="file.size">({{ formatFileSize(file.size) }})</span>
          </t-li>
        </t-ul>
      </div>

      <!-- Config Mode Selection -->
      <div class="config-mode-section">
        <t-radio-group v-model="useCustomConfig" class="mode-radio-group">
          <t-radio-button :value="false">
            {{ $t('uploadConfig.useDefault') }}
          </t-radio-button>
          <t-radio-button :value="true">
            {{ $t('uploadConfig.useCustom') }}
          </t-radio-button>
        </t-radio-group>
      </div>

      <!-- Chunking Settings (only shown when custom config is enabled) -->
      <div v-if="useCustomConfig" class="chunking-settings-section">
        <KBChunkingSettings :config="localConfig" @update:config="handleConfigUpdate" />
      </div>

      <!-- Action Buttons -->
      <div class="dialog-footer">
        <t-button theme="default" variant="outline" @click="handleCancel">
          {{ $t('common.cancel') }}
        </t-button>
        <t-button theme="primary" @click="handleConfirm">
          {{ $t('common.confirm') }}
        </t-button>
      </div>
    </div>
  </t-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import KBChunkingSettings from '@/views/knowledge/settings/KBChunkingSettings.vue'

interface FileItem {
  name: string
  size?: number
}

interface ChunkingConfig {
  chunkSize: number
  chunkOverlap: number
  separators: string[]
  enableParentChild: boolean
  parentChunkSize: number
  childChunkSize: number
  // Support snake_case from backend
  chunk_size?: number
  chunk_overlap?: number
  enable_parent_child?: boolean
  parent_chunk_size?: number
  child_chunk_size?: number
}

interface Props {
  visible: boolean
  files: FileItem[]
  kbChunkingConfig?: ChunkingConfig
}

const props = withDefaults(defineProps<Props>(), {
  kbChunkingConfig: () => ({
    chunkSize: 512,
    chunkOverlap: 50,
    separators: ['\n\n', '\n', '.'],
    enableParentChild: false,
    parentChunkSize: 4096,
    childChunkSize: 384
  })
})

const emit = defineEmits<{
  'update:visible': [value: boolean]
  'confirm': [config: ChunkingConfig | null]
  'cancel': []
}>()

const { t } = useI18n()

const useCustomConfig = ref(false)
const localConfig = ref<ChunkingConfig>({
  chunkSize: 512,
  chunkOverlap: 50,
  separators: ['\n\n', '\n', '.'],
  enableParentChild: false,
  parentChunkSize: 4096,
  childChunkSize: 384
})

const title = computed(() => {
  return props.files.length > 1
    ? t('uploadConfig.batchUploadTitle')
    : t('uploadConfig.singleUploadTitle')
})

const displayFiles = computed(() => {
  if (props.files.length <= 5) {
    return props.files
  }
  return [
    ...props.files.slice(0, 5),
    { name: t('uploadConfig.moreFiles', { count: props.files.length - 5 }) }
  ]
})

// Initialize config when dialog opens
watch(() => props.visible, (newVal) => {
  if (newVal) {
    useCustomConfig.value = false
    // Deep copy KB config (support both snake_case from backend and camelCase)
    localConfig.value = {
      chunkSize: props.kbChunkingConfig?.chunkSize || props.kbChunkingConfig?.chunk_size || 512,
      chunkOverlap: props.kbChunkingConfig?.chunkOverlap || props.kbChunkingConfig?.chunk_overlap || 50,
      separators: props.kbChunkingConfig?.separators ? [...props.kbChunkingConfig.separators] : ['\n\n', '\n', '.'],
      enableParentChild: props.kbChunkingConfig?.enableParentChild ?? props.kbChunkingConfig?.enable_parent_child ?? false,
      parentChunkSize: props.kbChunkingConfig?.parentChunkSize || props.kbChunkingConfig?.parent_chunk_size || 4096,
      childChunkSize: props.kbChunkingConfig?.childChunkSize || props.kbChunkingConfig?.child_chunk_size || 384
    }
  }
}, { immediate: true })

// Sync local config when KB config changes
watch(() => props.kbChunkingConfig, (newConfig) => {
  if (newConfig) {
    localConfig.value = {
      chunkSize: newConfig.chunkSize || newConfig.chunk_size || 512,
      chunkOverlap: newConfig.chunkOverlap || newConfig.chunk_overlap || 50,
      separators: newConfig.separators ? [...newConfig.separators] : ['\n\n', '\n', '.'],
      enableParentChild: newConfig.enableParentChild ?? newConfig.enable_parent_child ?? false,
      parentChunkSize: newConfig.parentChunkSize || newConfig.parent_chunk_size || 4096,
      childChunkSize: newConfig.childChunkSize || newConfig.child_chunk_size || 384
    }
  }
}, { deep: true })

const formatFileSize = (bytes: number): string => {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB'
}

// Handle config update from KBChunkingSettings
const handleConfigUpdate = (newConfig: ChunkingConfig) => {
  localConfig.value = { ...newConfig }
}

const handleClose = () => {
  // t-dialog close event - emit cancel for parent to clean up
  emit('cancel')
  emit('update:visible', false)
}

const handleCancel = () => {
  // Cancel button clicked - close dialog and emit cancel
  emit('cancel')
  emit('update:visible', false)
}

const handleConfirm = () => {
  if (useCustomConfig.value) {
    // Return a deep copy of the current config
    emit('confirm', {
      chunkSize: localConfig.value.chunkSize,
      chunkOverlap: localConfig.value.chunkOverlap,
      separators: [...localConfig.value.separators],
      enableParentChild: localConfig.value.enableParentChild,
      parentChunkSize: localConfig.value.parentChunkSize,
      childChunkSize: localConfig.value.childChunkSize
    })
  } else {
    emit('confirm', null)
  }
  emit('update:visible', false)
}
</script>

<style lang="less" scoped>
.upload-config-dialog {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.file-list-section {
  .section-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--td-text-color-primary);
    margin-bottom: 12px;
  }

  :deep(.t-ul) {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  :deep(.t-li) {
    padding: 8px 12px;
    background: var(--td-bg-color-container);
    border-radius: 4px;
    margin-bottom: 8px;
    font-size: 14px;
    color: var(--td-text-color-primary);

    .file-name {
      font-weight: 500;
    }

    .file-size {
      color: var(--td-text-color-secondary);
      margin-left: 8px;
    }
  }
}

.config-mode-section {
  .mode-radio-group {
    display: flex;
    width: 100%;

    :deep(.t-radio-button) {
      flex: 1;
      text-align: center;
    }
  }
}

.chunking-settings-section {
  max-height: 500px;
  overflow-y: auto;
  padding: 16px;
  background: var(--td-bg-color-container);
  border-radius: 8px;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding-top: 16px;
  border-top: 1px solid var(--td-component-stroke);
}
</style>
