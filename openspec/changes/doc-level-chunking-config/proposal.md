## Why

当前分块配置仅在知识库级别，用户无法针对不同文档类型（如技术手册 vs 对话记录）设置不同的分块策略。这导致检索效果无法最优化。

## What Changes

- **新增**：上传文件时支持自定义分块配置对话框
- **新增**：文档级别 `chunking_config` 字段（可选，为空时使用知识库配置）
- **新增**：分块配置复用逻辑（文档配置 > 知识库配置）
- **修改**：文件上传 API 支持可选的 `chunking_config` 参数
- **修改**：分块处理逻辑支持文档级配置优先级

**BREAKING**: 无（向后兼容，`chunking_config` 为可选参数）

## Capabilities

### New Capabilities

- `doc-level-chunking-config`: 文档级别的分块配置能力，支持在上传文件时自定义分块参数（ChunkSize、ChunkOverlap、Separators、EnableParentChild、ParentChunkSize、ChildChunkSize）
- `upload-config-dialog`: 上传配置对话框 UI 组件，提供文件上传前的分块配置界面，支持"使用知识库默认"和"自定义配置"两种模式

### Modified Capabilities

无

## Impact

- **前端**：
  - 新增 `UploadConfigDialog` 组件
  - 修改 `KnowledgeBase.vue` 上传流程
  - 修改 `platform/index.vue` 全局拖拽上传流程
  - 修改 `api/knowledge-base/index.ts` API 调用

- **后端**：
  - `handler/knowledge.go`: `CreateKnowledgeFromFile` 新增解析 `chunking_config` 参数
  - `service/knowledge.go`: `processDocument` 支持文档级配置优先级
  - `types/knowledge.go`: `Knowledge` 结构新增 `ChunkingConfig` 字段

- **数据库**：
  - `knowledge` 表新增 `chunking_config` JSON 字段

- **向后兼容**：
  - API 保持向后兼容（不传 `chunking_config` 时使用知识库配置）
  - 现有上传流程不受影响
