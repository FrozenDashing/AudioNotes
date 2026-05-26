# 语音待办 APP 下一步执行指南（保留 SQLite 版）

## 1. 项目目标

这个项目是一个**纯语音快速录入的待办记事 APP**，核心体验是：

* 用户打开 App 就能直接录音
* 语音自动转文字，生成待办
* 待办默认按时间顺序排列
* 不强制分类，不强制填时间
* 以后可逐步扩展：提醒、重复、分类、标签、筛选

当前技术栈：

* Flutter
* Riverpod
* Vosk 离线识别
* SQLite（sqflite）
* 原生录音 / 音频文件保存

---

## 2. 现有项目基础（AI 接手前必须先理解）

从当前代码看，项目已经不是空白工程，而是有一套可运行的基础链路：

### 2.1 已有能力

* 录音：`RecorderService`
* 离线识别：`RecognitionService` + `Vosk`
* 模型下载与切换：`ModelManagerService`
* 待办存储：`DatabaseHelper` + `TodoRepository`
* 页面展示：`HomeScreen` + `TodoItemCard`
* 全局状态：Riverpod providers
* 设置与主题：`SettingsService` / `SettingsProvider`

### 2.2 当前数据流

录音的核心流程已经搭好：

1. 用户按下录音按钮
2. 录音结束后得到 wav 文件路径
3. 先插入一条“识别中”状态的待办
4. 用 Vosk 做离线识别
5. 识别成功后更新待办文本
6. 列表刷新显示结果

这说明当前项目最关键的“语音到待办”主链路已经存在。

---

## 3. 当前代码的关键结构

### 3.1 数据层

* `lib/data/database_helper.dart`

  * 已经负责 SQLite 初始化、建表、查询、更新、删除
* `lib/data/todo_repository.dart`

  * 已经封装了待办的创建、识别完成、失败标记、删除等逻辑

### 3.2 领域层

* `lib/domain/usecases/create_todo_from_recording_usecase.dart`

  * 这是当前最核心的业务流程：录音结束 → 建记录 → 识别 → 写回数据库

### 3.3 模型层

* `lib/models/todo_item.dart`

  * 当前待办实体已经包含：

    * `id`
    * `text`
    * `createdAt`
    * `updatedAt`
    * `audioPath`
    * `taskState`
    * `status`
    * `durationMs`
    * `errorMessage`
    * `modelVersion`
    * `orderIndex`
    * `confidence`
    * `meta`

### 3.4 展示层

* `lib/screens/home_screen.dart`
* `lib/widgets/todo_item_card.dart`

### 3.5 语音与模型

* `lib/services/recorder_service.dart`
* `lib/services/recognition_service.dart`
* `lib/services/model_manager_service.dart`

---

## 4. 下一阶段的产品目标

你现在要做的不是“加很多功能”，而是把 MVP 之后最实用的增强功能拆成稳定模块。

本阶段的目标只包括两大块：

### A. 时间 & 提醒

* 给待办设置截止时间
* 给待办设置提醒时间
* 到点本地通知 + 弹窗 + 语音提醒
* 每日重复 / 每周重复
* 简易时间标签：今天 / 明天 / 本周

### B. 分类 & 标签

* 预设分类：生活、工作、私事、预约等
* 支持自定义标签
* 支持按分类筛选
* 分类功能可关闭，保持极简

---

## 5. 推荐的开发顺序

不要同时做太多功能。建议按下面顺序推进：

### 第 1 步：先升级数据结构 --finished!

先把 SQLite 表结构补齐，否则后面每加一个功能都要返工。

#### 要补的字段

* `dueAt`：截止时间
* `remindAt`：提醒时间
* `repeatType`：不重复 / 每日 / 每周
* `repeatRule`：重复规则内容
* `categoryId`：分类 ID
* `pinned`：是否置顶
* `completedAt`：完成时间
* `deletedAt`：软删除时间（可选）
* `rawTranscript`：识别原文，便于纠错

### 第 2 步：做提醒系统 --developing!

先只做最基础的本地提醒，不做复杂自然语言。

### 第 3 步：做分类和标签

先做最小可用版本：

* 分类可选
* 标签可选
* 默认不强制填写

### 第 4 步：做筛选和展示优化

* 按分类筛选
* 按时间状态筛选
* 隐藏/折叠已完成事项

### 第 5 步：再考虑同步和高级能力

* 云同步
* 导出导入
* 多设备迁移

---

## 6. SQLite 结构重构建议

当前项目已经使用 SQLite，所以建议继续保留，不要切换到其他数据层。

### 6.1 为什么要重构表结构

现在的 `todo_item` 表已经能支撑基础功能，但还不足以承载：

* 提醒时间
* 重复任务
* 分类
* 标签
* 筛选

这些都属于“扩展型业务字段”，最好从一开始就规划好。

---

### 6.2 推荐表结构

#### 主表：`todos`

保存待办核心信息。

字段建议：

* `id TEXT PRIMARY KEY`
* `text TEXT NOT NULL`
* `raw_text TEXT`
* `created_at INTEGER NOT NULL`
* `updated_at INTEGER`
* `audio_path TEXT`
* `task_state INTEGER NOT NULL DEFAULT 2`
* `status INTEGER NOT NULL DEFAULT 0`
* `duration_ms INTEGER`
* `error_message TEXT`
* `model_version TEXT`
* `order_index INTEGER`
* `confidence REAL`
* `meta TEXT`
* `due_at INTEGER`
* `remind_at INTEGER`
* `repeat_type INTEGER DEFAULT 0`
* `repeat_rule TEXT`
* `category_id TEXT`
* `pinned INTEGER DEFAULT 0`
* `completed_at INTEGER`
* `deleted_at INTEGER`

#### 分类表：`categories`

* `id TEXT PRIMARY KEY`
* `name TEXT NOT NULL`
* `color INTEGER`
* `sort_order INTEGER DEFAULT 0`
* `is_hidden INTEGER DEFAULT 0`

#### 标签表：`tags`

* `id TEXT PRIMARY KEY`
* `name TEXT NOT NULL`
* `color INTEGER`

#### 待办-标签关联表：`todo_tags`

* `todo_id TEXT NOT NULL`
* `tag_id TEXT NOT NULL`
* 联合主键：`(todo_id, tag_id)`

#### 提醒表：`reminders`

如果未来一个待办允许多个提醒，建议单独拆表：

* `id TEXT PRIMARY KEY`
* `todo_id TEXT NOT NULL`
* `remind_at INTEGER NOT NULL`
* `fired INTEGER DEFAULT 0`

---

## 7. 数据层该怎么拆

建议把数据层拆成下面几个职责，避免一个类越写越乱。

### 7.1 `DatabaseHelper`

职责：

* 管理 SQLite 初始化
* 创建表
* 版本升级
* 执行底层 SQL

不要把复杂业务逻辑塞进这里。

### 7.2 `TodoRepository`

职责：

* 创建待办
* 更新待办
* 删除待办
* 查询待办列表
* 完成/未完成切换
* 排序更新

### 7.3 新增 `ReminderRepository`

职责：

* 保存提醒时间
* 查询待触发提醒
* 标记提醒已触发

### 7.4 新增 `CategoryRepository`

职责：

* 获取预设分类
* 新建自定义分类
* 编辑/隐藏分类

### 7.5 新增 `TagRepository`

职责：

* 新建标签
* 删除标签
* 绑定/解绑待办标签

---

## 8. 时间 & 提醒功能的执行方案

### 8.1 MVP 最小版本

先不要做自然语言识别。先支持手动设置：

* 截止时间
* 提醒时间
* 重复类型

### 8.2 建议的 UI 交互

在待办详情页或编辑弹窗中增加：

* 设为今天
* 设为明天
* 设为本周
* 选择日期时间
* 是否提醒
* 是否重复

### 8.3 本地通知实现

建议使用：

* `flutter_local_notifications`
* `timezone`

通知内容建议包含：

* 待办标题
* 分类名（可选）
* 重复标记（可选）

### 8.4 提醒触发后的行为

到点后执行：

* 弹出通知
* App 内弹窗提醒
* 播放语音提示

### 8.5 重复任务的最小规则

先只做：

* 每日重复
* 每周重复

重复触发后：

* 自动生成下一次提醒时间
* 或在原任务上更新下一次触发时间

MVP 阶段不建议做太复杂的 cron 式规则。

---

## 9. 分类 & 标签功能的执行方案

### 9.1 产品原则

分类和标签必须是“可选项”，不能打断语音快速录入。

也就是说：

* 用户先说话，先记下来
* 分类和标签可以后补
* 不填也能用

### 9.2 预设分类建议

先内置这些：

* 生活
* 工作
* 私事
* 预约
* 学习

### 9.3 标签建议

标签适合做更细的标记，例如：

* 重要
* 紧急
* 家庭
* 健康
* 财务

### 9.4 分类与标签的区别

* 分类：一个待办通常只选一个
* 标签：一个待办可以多个

所以数据库设计里：

* 分类用 `category_id`
* 标签用 `todo_tags` 关联表

### 9.5 筛选功能

建议支持：

* 按分类筛选
* 按标签筛选
* 按完成状态筛选
* 按时间范围筛选

---

## 10. 对当前代码的具体改造建议

### 10.1 `TodoItem` 模型要扩展

建议把核心字段显式加入模型，不要全塞 `meta`。

优先加入：

* `dueAt`
* `remindAt`
* `repeatType`
* `repeatRule`
* `categoryId`
* `tagIds` 或 `tagsJson`
* `completedAt`
* `deletedAt`
* `rawTranscript`

### 10.2 `DatabaseHelper` 需要升级版本号

每次表结构变动后：

* 提升数据库版本号
* 在 `onUpgrade` 中做迁移
* 老用户数据不能丢

### 10.3 `TodoRepository` 需要新增方法

建议增加：

* `updateDueAt`
* `updateRemindAt`
* `setRepeatRule`
* `setCategory`
* `setTags`
* `getTodosByCategory`
* `getTodosByTag`
* `getTodosDueToday`
* `getTodosDueTomorrow`
* `getTodosThisWeek`

### 10.4 `HomeScreen` 需要增加筛选入口

建议在首页顶部或底部增加轻量筛选条：

* 全部
* 今天
* 明天
* 本周
* 已完成
* 分类

### 10.5 `TodoItemCard` 需要展示时间信息

在卡片上可显示：

* 截止时间
* 提醒标记
* 分类名
* 标签名

但仍保持极简，不要堆太多视觉元素。

---

## 11. 推荐的模块拆分图

### 11.1 数据与业务

* `database_helper.dart`
* `todo_repository.dart`
* `category_repository.dart`
* `tag_repository.dart`
* `reminder_repository.dart`

### 11.2 服务层

* `recorder_service.dart`
* `recognition_service.dart`
* `model_manager_service.dart`
* `notification_service.dart`
* `repeat_rule_service.dart`

### 11.3 UI 层

* `home_screen.dart`
* `todo_detail_screen.dart`
* `category_picker.dart`
* `tag_picker.dart`
* `reminder_picker.dart`

---

## 12. 开发里程碑建议

### Milestone 1：数据结构升级

完成内容：

* 扩展 `TodoItem`
* SQLite 增加提醒字段
* 准备分类表和标签表

验收标准：

* 老数据不丢
* 新字段可以正常读写

### Milestone 2：提醒功能

完成内容：

* 选择提醒时间
* 本地通知
* 到点弹窗

验收标准：

* 指定时间能准确触发
* 通知内容正确

### Milestone 3：重复任务

完成内容：

* 每日重复
* 每周重复

验收标准：

* 到期后能自动生成下一次

### Milestone 4：分类与标签

完成内容：

* 预设分类
* 自定义标签
* 筛选列表

验收标准：

* 不影响语音录入主流程
* 能按分类筛选

---

## 13. 给 AI 接手开发时的提示词模板

如果后续再让 AI 继续开发，可以直接使用这段要求：

> 你现在接手的是一个 Flutter + Vosk + SQLite 的语音待办 App。当前已经完成录音、离线识别、待办列表展示和基础 SQLite 持久化。现在要在保留 SQLite 的前提下，增加时间提醒、重复任务、分类和标签功能。请优先保持“语音快速录入、不强制分类、不强制时间”的产品原则，先做最小可用版本，再逐步扩展。输出时请先给出数据结构设计，再给出 repository 层、service 层、UI 层的改造方案，最后给出迁移步骤和验收标准。

---

## 14. 最推荐的实际落地顺序

最稳妥的顺序是：

1. 先改 SQLite schema
2. 再改 `TodoItem`
3. 再补 repository
4. 再接通知服务
5. 再做分类/标签 UI
6. 最后做筛选和重复逻辑

---

## 15. 这版 MVP 之后的方向

等以上功能稳定后，再考虑：

* 云同步
* 换机恢复
* 语音自然语言解析
* 悬浮球快捷录音
* 搜索
* 归档

这些都属于下一阶段，不要在当前阶段抢着做。
