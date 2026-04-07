<template>
    <div class="main" ref="dropzone">
        <Menu></Menu>
        <RouterView />
        <div class="upload-mask" v-show="ismask">
            <input type="file" style="display: none" ref="uploadInput" accept=".pdf,.docx,.doc,.pptx,.ppt,.txt,.md,.jpg,.jpeg,.png,.csv,.xls,.xlsx" />
            <UploadMask></UploadMask>
        </div>
        <!-- 全局设置模态框，供所有 platform 子路由使用 -->
        <Settings />
        <!-- Upload Config Dialog for global drag-and-drop -->
        <UploadConfigDialog
            v-model:visible="showUploadConfigDialog"
            :files="pendingUploadFiles.map(f => ({ name: f.name, size: f.size }))"
            :kb-chunking-config="currentKbChunkingConfig"
            @confirm="handleGlobalUploadConfirm"
            @cancel="pendingUploadFiles = []"
        />
    </div>
</template>
<script setup lang="ts">
import Menu from '@/components/menu.vue'
import { ref, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router'
import useKnowledgeBase from '@/hooks/useKnowledgeBase'
import UploadMask from '@/components/upload-mask.vue'
import Settings from '@/views/settings/Settings.vue'
import UploadConfigDialog from '@/components/UploadConfigDialog.vue'
import { getKnowledgeBaseById } from '@/api/knowledge-base/index'
import { uploadKnowledgeFile } from '@/api/knowledge-base/index'
import { MessagePlugin } from 'tdesign-vue-next'
import { useI18n } from 'vue-i18n'
import { useUIStore } from '@/stores/ui'

let { requestMethod } = useKnowledgeBase()
const route = useRoute();
let ismask = ref(false)
let uploadInput = ref();
const { t } = useI18n();
const uiStore = useUIStore();

// Upload config dialog state for global drag-and-drop
const showUploadConfigDialog = ref(false);
const pendingUploadFiles = ref<File[]>([]);
const currentKbChunkingConfig = ref<any>(null);
const currentKbIdForUpload = ref<string | null>(null);

// 用于跟踪拖拽进入/离开的计数器，解决子元素触发 dragleave 的问题
let dragCounter = 0;

// 获取当前知识库ID
const getCurrentKbId = (): string | null => {
    return (route.params as any)?.kbId as string || null
}

// 检查知识库初始化状态
const checkKnowledgeBaseInitialization = async (): Promise<boolean> => {
    const currentKbId = getCurrentKbId();
    
    if (!currentKbId) {
        MessagePlugin.error(t('knowledgeBase.missingId'));
        return false;
    }
    
    try {
        const kbResponse = await getKnowledgeBaseById(currentKbId);
        const kb = kbResponse.data;
        
        if (!kb.embedding_model_id || !kb.summary_model_id) {
            MessagePlugin.warning(t('knowledgeBase.notInitialized'));
            return false;
        }
        return true;
    } catch (error) {
        MessagePlugin.error(t('knowledgeBase.getInfoFailed'));
        return false;
    }
}


// 全局拖拽事件处理
const handleGlobalDragEnter = (event: DragEvent) => {
    event.preventDefault();
    dragCounter++;
    if (event.dataTransfer) {
        event.dataTransfer.effectAllowed = 'all';
    }
    ismask.value = true;
}

const handleGlobalDragOver = (event: DragEvent) => {
    event.preventDefault();
    if (event.dataTransfer) {
        event.dataTransfer.dropEffect = 'copy';
    }
}

const handleGlobalDragLeave = (event: DragEvent) => {
    event.preventDefault();
    dragCounter--;
    if (dragCounter === 0) {
        ismask.value = false;
    }
}

const handleGlobalDrop = async (event: DragEvent) => {
    event.preventDefault();
    dragCounter = 0;
    ismask.value = false;

    const DataTransferFiles = event.dataTransfer?.files ? Array.from(event.dataTransfer.files) : [];
    const DataTransferItemList = event.dataTransfer?.items ? Array.from(event.dataTransfer.items) : [];

    const currentKbId = getCurrentKbId();
    if (!currentKbId) {
        MessagePlugin.error(t('knowledgeBase.missingId'));
        return;
    }

    const isInitialized = await checkKnowledgeBaseInitialization();
    if (!isInitialized) {
        return;
    }

    // Get KB config for dialog pre-fill
    try {
        const kbResponse = await getKnowledgeBaseById(currentKbId);
        currentKbChunkingConfig.value = kbResponse.data?.chunking_config || null;
    } catch (error) {
        // Continue with null config
    }

    const validFiles: File[] = [];

    if (DataTransferFiles.length > 0) {
        for (const file of DataTransferFiles) {
            if (file instanceof File) {
                validFiles.push(file);
            }
        }
    } else if (DataTransferItemList.length > 0) {
        // Handle FileSystemFileEntry asynchronously
        const filePromises: Promise<File>[] = [];
        DataTransferItemList.forEach(dataTransferItem => {
            const fileEntry = dataTransferItem.webkitGetAsEntry() as FileSystemFileEntry | null;
            if (fileEntry) {
                const filePromise = new Promise<File>((resolve) => {
                    fileEntry.file((file: File) => resolve(file));
                });
                filePromises.push(filePromise);
            }
        });
        const files = await Promise.all(filePromises);
        validFiles.push(...files);
    } else {
        MessagePlugin.warning(t('knowledgeBase.dragFileNotText'));
        return;
    }

    if (validFiles.length === 0) {
        return;
    }

    // Store files and show config dialog
    pendingUploadFiles.value = validFiles;
    currentKbIdForUpload.value = currentKbId;
    showUploadConfigDialog.value = true;
}

// Handle upload config dialog confirm for global drag-and-drop
const handleGlobalUploadConfirm = async (chunkingConfig: any) => {
    const validFiles = pendingUploadFiles.value;
    const kbId = currentKbIdForUpload.value;
    if (validFiles.length === 0 || !kbId) return;

    const tagIdToUpload = uiStore.selectedTagId !== '__untagged__' ? uiStore.selectedTagId : undefined;

    let successCount = 0;
    let failCount = 0;

    for (const file of validFiles) {
        try {
            const uploadData: any = { file, tag_id: tagIdToUpload };
            // Add chunking_config if provided (convert camelCase to snake_case for backend)
            if (chunkingConfig) {
                uploadData.chunking_config = JSON.stringify({
                    chunk_size: chunkingConfig.chunkSize,
                    chunk_overlap: chunkingConfig.chunkOverlap,
                    separators: chunkingConfig.separators,
                    enable_parent_child: chunkingConfig.enableParentChild,
                    parent_chunk_size: chunkingConfig.parentChunkSize,
                    child_chunk_size: chunkingConfig.childChunkSize
                });
            }
            await uploadKnowledgeFile(kbId, uploadData);
            successCount++;
        } catch (error: any) {
            failCount++;
        }
    }

    if (successCount > 0) {
        MessagePlugin.success(t('knowledgeBase.uploadSuccess'));
        // Refresh knowledge list if on knowledge base page
        window.dispatchEvent(new CustomEvent('knowledgeFileUploaded', {
            detail: { kbId }
        }));
    }

    if (failCount > 0 && successCount === 0) {
        MessagePlugin.error(t('knowledgeBase.uploadFailed'));
    } else if (failCount > 0) {
        MessagePlugin.warning(t('knowledgeBase.uploadPartialSuccess', { success: successCount, fail: failCount }));
    }

    // Clear pending files
    pendingUploadFiles.value = [];
    currentKbIdForUpload.value = null;
};

// 组件挂载时添加全局事件监听器
onMounted(() => {
    document.addEventListener('dragenter', handleGlobalDragEnter, true);
    document.addEventListener('dragover', handleGlobalDragOver, true);
    document.addEventListener('dragleave', handleGlobalDragLeave, true);
    document.addEventListener('drop', handleGlobalDrop, true);
});

// 组件卸载时移除全局事件监听器
onUnmounted(() => {
    document.removeEventListener('dragenter', handleGlobalDragEnter, true);
    document.removeEventListener('dragover', handleGlobalDragOver, true);
    document.removeEventListener('dragleave', handleGlobalDragLeave, true);
    document.removeEventListener('drop', handleGlobalDrop, true);
    dragCounter = 0;
});
</script>
<style lang="less">
.main {
    display: flex;
    width: 100%;
    height: 100%;
    min-width: 600px;
    /* 统一整页背景，让左侧菜单与右侧内容区视觉连贯 */
    background: var(--td-bg-color-container);
}

.upload-mask {
    background-color: rgba(255, 255, 255, 0.8);
    position: fixed;
    width: 100%;
    height: 100%;
    z-index: 999;
    display: flex;
    justify-content: center;
    align-items: center;
}

img {
    -webkit-user-drag: none;
    -khtml-user-drag: none;
    -moz-user-drag: none;
    -o-user-drag: none;
    user-drag: none;
}
</style>