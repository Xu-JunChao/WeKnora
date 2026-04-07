## ADDED Requirements

### Requirement: 文档级分块配置存储
系统 SHALL 支持在知识（Knowledge）级别存储分块配置（chunking_config），该配置为可选字段，为空时表示使用知识库级别的配置。

#### Scenario: 创建知识时不指定分块配置
- **WHEN** 用户上传文件且不指定 chunking_config
- **THEN** 知识的 chunking_config 字段为 NULL，处理时使用知识库配置

#### Scenario: 创建知识时指定分块配置
- **WHEN** 用户上传文件并指定 chunking_config
- **THEN** 知识的 chunking_config 字段保存用户配置的值

#### Scenario: 文档配置优先级高于知识库配置
- **WHEN** 知识有 chunking_config 且知识库也有 ChunkingConfig
- **THEN** 处理该知识时使用文档级的 chunking_config

### Requirement: 文档级分块配置字段
系统 SHALL 支持以下分块配置字段：
- ChunkSize (int): 块大小，范围 100-8192
- ChunkOverlap (int): 重叠大小，范围 0-1000
- Separators ([]string): 分隔符列表
- EnableParentChild (bool): 是否启用父子分块
- ParentChunkSize (int): 父块大小，范围 512-8192
- ChildChunkSize (int): 子块大小，范围 64-2048

#### Scenario: ChunkSize 有效范围
- **WHEN** ChunkSize 在 100-8192 范围内
- **THEN** 配置有效

#### Scenario: ChunkOverlap 不能超过 ChunkSize
- **WHEN** ChunkOverlap >= ChunkSize
- **THEN** 配置无效，返回错误

#### Scenario: ParentChunkSize 不能小于 ChildChunkSize
- **WHEN** EnableParentChild=true 且 ParentChunkSize < ChildChunkSize
- **THEN** 配置无效，返回错误

### Requirement: 分块处理配置优先级
系统 SHALL 按照以下优先级使用分块配置：
1. 文档级 chunking_config（如果存在）
2. 知识库 ChunkingConfig
3. 系统默认值（ChunkSize=512, ChunkOverlap=50, Separators=["\n\n", "\n", "."]）

#### Scenario: 使用文档级配置
- **WHEN** 知识有 chunking_config
- **THEN** 使用文档级配置进行分块

#### Scenario: 使用知识库配置
- **WHEN** 知识没有 chunking_config
- **THEN** 使用知识库配置进行分块

#### Scenario: 使用系统默认值
- **WHEN** 知识和知识库都没有配置，或配置值为 0/空
- **THEN** 使用系统默认值进行分块

## MODIFIED Requirements

### Requirement: 文件上传 API
原需求：用户 SHALL 能够通过文件上传接口上传文件到知识库

修改后：用户 SHALL 能够通过文件上传接口上传文件到知识库，并可选地指定文档级分块配置（chunking_config）。chunking_config 为可选参数，不传时使用知识库配置。

#### Scenario: 上传文件不传配置
- **WHEN** 用户调用上传 API 不传 chunking_config
- **THEN** 文件上传成功，使用知识库配置处理

#### Scenario: 上传文件传入配置
- **WHEN** 用户调用上传 API 传入 chunking_config
- **THEN** 文件上传成功，使用文档级配置处理

#### Scenario: 向后兼容
- **WHEN** 现有代码调用上传 API（不传 chunking_config）
- **THEN** 行为与之前版本一致，使用知识库配置
