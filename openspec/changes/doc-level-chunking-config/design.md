## Context

**背景**：
- WeKnora 当前的分块配置（ChunkingConfig）存储在知识库级别
- 用户上传文件时，所有文档使用相同的分块配置
- 不同文档类型（技术文档、对话记录、合同等）可能需要不同的分块策略

**现状**：
- 上传流程：选择文件 → 直接上传 → 后端使用 KB 配置分块
- 配置字段：ChunkSize, ChunkOverlap, Separators, EnableParentChild, ParentChunkSize, ChildChunkSize
- UI 组件：`KBChunkingSettings.vue` 已有完整的分块配置界面

**约束**：
- 必须向后兼容（现有 API 调用不能失败）
- 默认值复用知识库配置（简化用户操作）
- 前端 UI 与知识库设置保持一致

## Goals / Non-Goals

**Goals:**
- 支持上传文件时自定义分块配置
- 文档级配置优先级高于知识库配置
- 保持 API 向后兼容
- 前端提供友好的配置对话框 UI
- 数据库新增 `knowledge.chunking_config` 字段

**Non-Goals:**
- 不支持批量修改已上传文件的分块配置（需删除后重新上传）
- 不支持基于文件类型的自动推荐配置
- 不支持 `ParserEngineRules` 字段（仅知识库级别配置）
- 不修改现有知识库设置 UI

## Decisions

### 1. 配置对话框触发时机

**决策**：文件选择后立即弹出配置对话框（点击上传或拖拽文件后）

**原因**：
- 用户在上传前明确知道可以自定义配置
- 可以选择"使用知识库默认"快速上传

**替代方案考虑**：
- 方案 B：上传后在通知中心配置 → 过于复杂，用户不易发现
- 方案 C：智能检测文件类型后推荐 → 增加实现复杂度，可后续扩展

### 2. 配置对话框默认状态

**决策**：默认选中"使用知识库默认配置"，配置值预填充为知识库配置

**原因**：
- 简化大多数用户的上传流程（点确认即可）
- 预填充配置值方便用户基于默认值微调

### 3. 批量上传配置方式

**决策**：多文件上传时，统一使用同一套配置

**原因**：
- 简化 UI 和交互逻辑
- 避免每个文件单独配置的繁琐操作

### 4. 后端配置验证

**决策**：简化验证，仅处理空值，依赖前端 UI 的范围限制

**原因**：
- 前端 Slider 组件已有 min/max 限制（ChunkSize: 100-4000, ChunkOverlap: 0-500）
- 分块逻辑本身有默认值兜底（ChunkSize<=0 → 512）
- 减少后端代码量

**替代方案考虑**：
- 完整后端验证 → 增加代码复杂度，收益低

### 5. 配置优先级逻辑

**决策**：文档配置 > 知识库配置 > 系统默认值

```go
var effectiveConfig *ChunkingConfig
if knowledge.ChunkingConfig != nil {
    effectiveConfig = knowledge.ChunkingConfig  // 文档级配置
} else {
    effectiveConfig = &kb.ChunkingConfig        // 知识库配置
}
// 分块逻辑内部处理 default 值
```

### 6. 数据库迁移

**决策**：新增 `knowledge.chunking_config JSON` 字段，允许 NULL

**原因**：
- NULL 表示使用知识库配置
- JSON 类型灵活，支持未来扩展

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 用户困惑于额外配置步骤 | 默认选中"使用知识库默认"，一键确认即可 |
| 后端处理异常值 | 分块逻辑有默认值兜底 |
| 数据库迁移失败 | 添加回滚 SQL，先添加字段不设置 NOT NULL |
| 第三方 API 调用不兼容 | 保持向后兼容，不传参数时行为不变 |
| 前端组件复用问题 | 抽取 `KBChunkingSettings` 为独立组件复用 |

## Migration Plan

### 部署步骤

1. **数据库迁移**
   ```sql
   ALTER TABLE knowledge ADD COLUMN chunking_config JSON;
   ```

2. **后端部署**
   - 更新 `types/knowledge.go`：新增 `ChunkingConfig` 字段
   - 更新 `handler/knowledge.go`：解析 `chunking_config` 参数
   - 更新 `service/knowledge.go`：支持文档级配置优先级

3. **前端部署**
   - 新增 `UploadConfigDialog.vue` 组件
   - 修改 `KnowledgeBase.vue` 上传流程
   - 修改 `platform/index.vue` 拖拽上传流程
   - 修改 `api/knowledge-base/index.ts` API

### 回滚策略

- 数据库：`ALTER TABLE knowledge DROP COLUMN chunking_config;`
- 后端：回滚到上一个版本（不读取 `chunking_config` 字段）
- 前端：回滚到上一个版本（不弹出配置对话框）

## Open Questions

无
