# HomeWidget RAG+：桌面小组件开发知识库与最小改动实现指南

> 目标：在现有 `Flutter + Riverpod + 本地数据库 + 业务服务层` 的代码架构下，稳定落地两个桌面小组件：
> 
> 1. **快速录音入口**：点击后直接唤起 App 内录音流程。
> 2. **Todo 快捷显示**：按尺寸自适应布局，展示“待办 / 本周 / 高优先级”，尽量省略冗余文字与高开销装饰。

---

## 1. 设计目标与约束

### 1.1 业务目标

- 桌面小组件要和 App 的核心动作打通。
- 录音入口要成为“桌面级快捷操作”，点击即进入录音流程。
- Todo widget 要成为“低负载摘要面板”，不是完整待办页面的缩小版。
- 支持按大小自动变化布局，避免固定写死一个 UI。

### 1.2 技术约束

- **本地优先**：主数据仍然以本地数据库为主。
- **轻同步**：widget 只消费“快照数据”，不直接绑定完整数据库。
- **低渲染开销**：少动画、少阴影、少复杂层级、少模糊。
- **最小改动**：尽量不重构现有 todo 业务链路，只在数据出口和入口做适配。
- **可调试**：每次 widget 刷新、点击、同步都要能追踪日志。

---

## 2. 三类知识库：RAG+ 的检索范围

### 2.1 代码知识库

回答“代码应该改哪里、怎么接线、哪个类负责什么”。

建议纳入：

- Flutter 入口：`lib/main.dart`
- Home / 录音页 / Todo 主界面
- `providers/`、`repositories/`、`services/`
- Android 原生入口：`MainActivity.kt`
- Android Widget Provider、布局 XML、点击跳转逻辑
- `home_widget` 数据桥接逻辑
- 路由 / deep link / action 参数处理逻辑

**检索重点**：

- widget 数据从哪里来
- Flutter 如何写快照
- 原生 widget 如何读快照
- 录音入口如何唤起录音动作
- widget 尺寸变化时如何切布局

### 2.2 设计知识库

回答“长什么样、什么信息必须保留、什么内容应该删掉”。

建议纳入：

- 录音 widget 的视觉规范
- Todo widget 的信息层级
- 不同尺寸的布局断点
- 字体大小策略
- 图标、颜色、间距、圆角、阴影强度
- 低渲染开销原则

**核心设计原则**：

- 录音 widget：一个主按钮 + 一行标题 + 一行说明即可。
- Todo widget：标题、分组、少量条目、数量徽标。
- 小尺寸时：只显示标题、组名、数量。
- 中尺寸时：显示组名 + 1～2 条条目。
- 大尺寸时：最多展示 3～4 条条目，但仍保持简洁。
- 不做复杂渐变背景、不做模糊玻璃、不做密集阴影。

### 2.3 调试知识库

回答“为什么没刷新、为什么点了没反应、为什么显示错位”。

建议纳入：

- Widget 不刷新的排查路径
- 点击 action 无效的排查路径
- 数据快照写入失败的排查路径
- 原生布局尺寸不匹配的排查路径
- Flutter 与原生之间 action 参数不一致的排查路径
- Android / iOS 平台差异问题

**排查关键词**：

- `saveWidgetData`
- `updateWidget`
- `PendingIntent`
- `deep link`
- `launchMode`
- `AppWidgetProvider`
- `background callback`
- `sizeVariant`
- `snapshot payload`

---

## 3. 现有代码架构下的推荐接入方式

### 3.1 推荐分层

#### Flutter 层

负责：

- 生成 widget 快照
- 保存 widget 配置
- 触发 widget 刷新
- 处理点击 widget 后进入 App 的行为
- 提供 widget 预览页

#### 数据层

负责：

- 从本地 todo 数据生成轻量快照
- 生成分组摘要
- 输出 widget 需要的最小字段

#### 原生层

负责：

- 系统桌面展示
- 尺寸适配
- 点击事件
- 快照读取
- widget 刷新

#### 同步层

负责：

- Flutter -> widget 数据桥接
- 数据变更后刷新桌面 widget
- 离线情况下保持一致性

---

## 4. widget 功能定义（按最新需求修订）

### 4.1 快速录音入口 widget

#### 目标

- 点击整个 widget 即可进入 App 的录音流程。
- 不在 widget 内做真正录音识别。
- 尽量少文字、少层级、少装饰。

#### 建议布局

- 中间：麦克风主按钮
- 下方：`快速录音`
- 可选一行极短说明：`点击开始录音`
- 底部不放额外按钮

#### 点击行为

- 打开 App
- 自动唤起录音页或录音底板
- 若需要，用参数标记进入“录音模式”

#### 建议不要做

- 在 widget 内直接录音
- 在 widget 内直接转文字
- 放多个功能按钮
- 放复杂状态机

### 4.2 Todo 快捷显示 widget

#### 目标

- 用最少信息展示最关键的待办概览。
- 组名要保留，但不做华丽卡片堆叠。
- 删除右上角“打开应用 >”。
- 使用“待办”替换“今日待办”。
- 分组从“今天/明天”改成“本周 / 高优先级”。
- 尺寸越小，省略越多。

#### 建议新的信息结构

- 顶部标题：`待办`
- 主体分组：
  - `本周`
  - `高优先级`
- 每组只显示少量条目
- 每组右侧显示数量徽标

#### 布局原则

- 小尺寸：
  - 只显示标题 + 2 个分组标题 + 数量
  - 条目可以隐藏
- 中尺寸：
  - 标题 + 分组 + 每组 1～2 条条目
- 大尺寸：
  - 标题 + 分组 + 每组最多 3～4 条条目

#### 建议不要做

- “今天 / 明天”日历化分组
- 右上角“打开应用 >”
- 过重阴影和玻璃拟态
- 每条目都带复杂时间样式

---

## 5. 小组件尺寸自适应策略

### 5.1 设计目标

让 widget 根据尺寸变化自动调整显示密度，而不是完全依赖手工选一个固定布局。

### 5.2 推荐做法

把布局分为三个档位：

#### Compact（紧凑）

适用：小尺寸 widget

显示内容：

- 标题
- 一个主图标或一个主分组提示
- 最少量文字

#### Standard（标准）

适用：常规尺寸 widget

显示内容：

- 标题
- 两个分组
- 每组 1～2 条条目

#### Expanded（展开）

适用：大尺寸 widget

显示内容：

- 标题
- 两个分组
- 每组 3～4 条条目
- 总数、更新时间等轻量元信息

### 5.3 约束原则

- 用尺寸做“信息密度切换”，不是换风格。
- 所有尺寸下都使用同一种视觉语言。
- 小尺寸时优先保留标题和分组名。
- 文字优先裁剪，而不是把布局撑爆。

---

## 6. Flutter 侧推荐实现方式

### 6.1 建议新增的服务

#### `WidgetSnapshotService`

职责：

- 将本地 todo 数据转换为 widget 快照。
- 按 widget 类型输出不同 payload。

#### `WidgetSyncService`

职责：

- 保存 widget 数据。
- 调用 widget 更新。
- 管理更新时间戳。

#### `WidgetLaunchService`

职责：

- 处理点击 widget 后的 App 启动逻辑。
- 根据 action 参数决定进入录音还是进入 Todo 首页。

### 6.2 快照结构建议

#### 快速录音 widget 快照

```json
{
  "type": "quick_record",
  "title": "快速录音",
  "subtitle": "点击开始录音",
  "action": "open_recording",
  "updatedAt": "2026-05-29T10:00:00Z",
  "sizeVariant": "compact"
}
```

#### Todo widget 快照

```json
{
  "type": "todo_summary",
  "title": "待办",
  "groups": [
    {
      "groupId": "this_week",
      "groupTitle": "本周",
      "count": 3,
      "items": ["准备项目汇报材料", "与团队同步进度"]
    },
    {
      "groupId": "high_priority",
      "groupTitle": "高优先级",
      "count": 2,
      "items": ["提交设计稿", "处理紧急反馈"]
    }
  ],
  "updatedAt": "2026-05-29T10:00:00Z",
  "sizeVariant": "standard"
}
```

---

## 7. 原生层推荐实现方式

### 7.1 录音 widget

原生 widget 负责：

- 展示静态卡片
- 接收点击事件
- 打开 App
- 携带 action 参数进入录音页

#### 点击建议

- 点击 widget 主体时使用 `PendingIntent` 打开主 App
- 通过 deep link 或 intent extra 携带 `open_recording=true`
- App 启动后由 Flutter 层解析该参数，并自动进入录音流程

### 7.2 Todo widget

原生 widget 负责：

- 读取快照 JSON
- 按 size variant 渲染不同布局
- 显示标题、组名、条目、数量
- 点击 widget 打开 App 首页

#### 尺寸适配建议

- 小 widget：只显示标题和组名
- 中 widget：加 1～2 条条目
- 大 widget：加更多条目，但仍保持低密度

---

## 8. 最小改动开发步骤

### 第一步：先定义数据格式

先不要急着写原生 UI，先把两个 widget 的快照格式定下来。

输出物：

- `quick_record` schema
- `todo_summary` schema
- `sizeVariant` 规则
- `action` 规则

### 第二步：先做 Flutter 预览页

在 App 内做两个 widget 的预览卡：

- 录音卡
- Todo 卡

预览页作用：

- 看信息密度
- 看尺寸切换
- 看文字是否会溢出

### 第三步：做快照同步

实现 Flutter 向 widget 写入快照并触发更新。

### 第四步：做原生静态 widget

先做最小功能：

- 能显示
- 能点击
- 能更新

### 第五步：再补尺寸适配和调试

最后补：

- compact / standard / expanded 三档布局
- debug 日志
- 空数据占位
- 错误回退

---

## 9. 代码库里的职责建议

### `lib/services/`

适合放：

- widget 快照生成
- widget 同步刷新
- widget 点击 action 处理

### `lib/repositories/`

适合放：

- widget 配置持久化
- 当前选中 widget 类型
- widget 尺寸偏好

### `lib/providers/`

适合放：

- widget 同步状态
- 网络状态
- 更新中状态
- 失败重试状态

### `lib/screens/`

适合放：

- widget 设置页
- widget 预览页
- widget 布局测试页

### Android 原生目录

适合放：

- AppWidgetProvider
- widget 布局 XML
- 点击跳转处理
- 快照读取逻辑

---

## 10. 调试与排查指南

### 10.1 widget 不刷新

优先检查：

1. Flutter 是否真的保存了快照。
2. 是否调用了 widget 更新方法。
3. 原生 widget 是否能读取到最新数据。
4. 数据 key 是否一致。
5. 是否使用了错误的 widget provider 名称。

### 10.2 点击没反应

优先检查：

1. `PendingIntent` 是否绑定到了正确 view。
2. Action 是否带到了 App 启动参数。
3. Flutter 是否解析了 deep link 或 intent extra。
4. 是否被系统限制了后台行为。

### 10.3 显示错位

优先检查：

1. 文本是否过长。
2. 布局是否超出 widget 尺寸。
3. 是否需要用 compact layout。
4. 是否把过多信息放进了小尺寸。

### 10.4 数据不同步

优先检查：

1. 本地数据库是否更新成功。
2. widget 快照是否同步成功。
3. 更新事件是否触发。
4. 是否存在多处写入源。

---

## 11. 给 AI Agent 的检索提示词

### 11.1 录音 widget

- 录音快捷入口
- 点击打开 App 并进入录音
- quick_record snapshot
- widget click action
- home_widget save and update

### 11.2 Todo widget

- Todo 快捷显示
- 待办 widget 分组
- 本周 高优先级
- compact standard expanded layout
- widget size variant

### 11.3 调试

- widget 不刷新
- 点击无响应
- 数据快照失败
- 原生布局错位
- intent 参数不传递

---

## 12. 直接可执行的设计约束

### 录音 widget

- 主按钮唯一
- 说明文字极短
- 点击即进入录音
- 不能塞太多状态

### Todo widget

- 标题改成 `待办`
- 分组改成 `本周 / 高优先级`
- 删除右上角“打开应用 >”
- 小尺寸自动隐藏次要文字
- 只保留必要条目

### 通用

- 低阴影
- 低层级
- 少动画
- 少模糊
- 少装饰
- 以信息可读性优先

---

## 13. 验收标准

### 录音 widget

- 点击后确实打开 App
- 自动进入录音流程或录音承接页
- 小组件本身看起来简洁明确

### Todo widget

- 顶部标题为 `待办`
- 分组显示 `本周` 与 `高优先级`
- 没有右上角“打开应用 >”
- 能根据尺寸自动减少/增加显示内容
- 小尺寸下不溢出、不拥挤

### 稳定性

- 快照更新成功
- widget 刷新成功
- 点击跳转成功
- 空数据也有合理占位

---

## 14. 推荐的最终实现顺序

1. 先定快照 schema。
2. 再做 Flutter 预览页。
3. 再做同步服务。
4. 再做原生 widget 布局。
5. 最后接点击录音与尺寸适配。

这样做能把风险控制住，而且任何一个阶段都可以单独验证。

---

## 15. 给接手 AI 的一句话摘要

> 这个项目的桌面小组件要走“本地快照 + 原生展示 + Flutter 同步”的最小改动路线。录音 widget 只负责打开 App 并进入录音流程，Todo widget 只显示“待办 / 本周 / 高优先级”的轻量摘要，所有布局都必须支持按尺寸自动缩放，并优先省略次要文字。
