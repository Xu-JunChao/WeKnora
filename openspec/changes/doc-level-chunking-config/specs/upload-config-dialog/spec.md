## ADDED Requirements

### Requirement: 上传配置对话框 UI
系统 SHALL 在用户选择文件后弹出上传配置对话框，提供分块配置选项。

#### Scenario: 对话框默认状态
- **WHEN** 对话框打开
- **THEN** 默认选中"使用知识库默认配置"选项，配置值预填充为知识库配置

#### Scenario: 使用知识库默认配置
- **WHEN** 用户选择"使用知识库默认配置"并点击确认
- **THEN** 不传 chunking_config 参数，直接上传文件

#### Scenario: 自定义配置
- **WHEN** 用户选择"自定义配置"并修改配置值
- **THEN** 传递自定义的 chunking_config 参数上传文件

#### Scenario: 取消上传
- **WHEN** 用户点击"取消"按钮
- **THEN** 关闭对话框，取消文件上传

### Requirement: 配置对话框字段
对话框 SHALL 包含以下配置字段，与知识库设置 UI 保持一致：
- 块大小（Slider, 100-4000, step 50）
- 重叠大小（Slider, 0-500, step 20）
- 分隔符（多选下拉框，支持自定义）
- 父子分块开关（Switch）
- 父块大小（Slider, 512-8192, step 64，仅在启用父子分块时显示）
- 子块大小（Slider, 64-2048, step 32，仅在启用父子分块时显示）

#### Scenario: 块大小调整
- **WHEN** 用户拖动块大小 Slider
- **THEN** 实时更新显示的值

#### Scenario: 父子分块联动
- **WHEN** 用户启用父子分块开关
- **THEN** 显示父块大小和子块大小配置项

#### Scenario: 配置值验证
- **WHEN** 用户输入超出范围的值
- **THEN** Slider 限制在有效范围内

### Requirement: 批量上传配置
系统 SHALL 支持多文件上传时使用统一的分块配置。

#### Scenario: 多文件统一配置
- **WHEN** 用户一次选择多个文件
- **THEN** 对话框显示所有文件列表，配置应用于所有文件

#### Scenario: 批量上传确认
- **WHEN** 用户点击确认
- **THEN** 所有文件使用同一配置依次上传

### Requirement: 全局拖拽上传支持
系统 SHALL 支持用户拖拽文件到页面任意位置触发上传配置对话框。

#### Scenario: 拖拽文件触发
- **WHEN** 用户拖拽文件到页面
- **THEN** 显示拖拽上传覆盖层，释放后弹出配置对话框

#### Scenario: 拖拽多文件
- **WHEN** 用户拖拽多个文件
- **THEN** 弹出配置对话框，显示所有文件列表
