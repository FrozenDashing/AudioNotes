# todo.md — 动画迁移进度记录

位置：本文件位于与 `audionote_flutter_animate_motion_spec.md` 同一目录，作为动画迁移的进度单一来源（SotA）。

## 一、总说明
本文件记录已按动画规范（迁移到 `flutter_animate`）完成的目标与剩余待办。所有以后对动画相关的源码变更必须同步更新本文件，以便保持进度与决策一致。


## 二、已完成（已实现并已提交）
- 已添加依赖并更新：`pubspec.yaml` 中加入 `flutter_animate`。
- 已建立统一 motion 层：`lib/utils/motion.dart`（`MotionTokens`、`motionEntrance`、`motionAllowed`）。
- 已在以下模块接入入口动画（使用 `motionEntrance` / 统一 token）：
  - `lib/widgets/todo_item_card.dart` — 卡片进入与对话框入口动画
  - `lib/widgets/todo_group_section.dart` — 分组项进入、折叠保留 `AnimatedSize`
  - `lib/screens/settings_screen.dart` 与子页面（`appearance`, `todo_settings`）— hub 与卡片入口动画
  - `lib/screens/model_selection_screen.dart` — 模型列表与下载按钮入口动画（并修复 async context 使用）
  - `lib/widgets/floating_action_toolbar.dart` — 浮动批量工具栏的进入动画
- 执行 `flutter pub get` 成功（依赖解析通过）。
- 运行 `flutter analyze`：已修复在迁移过程中发现的问题，最终分析结果为 "No issues found"。


## 三、待办（尚未实现）
- 在 `lib/screens/home_screen.dart` 中迁移并统一底部弹层（排序、模型下载、编辑表单等）的内部进入/退出动效 — 状态：已完成（排序底部表单与模型下载对话框已使用 `motionEntrance` 封装）。
- 迁移选择器/弹出列表（例如 `category_picker_screen.dart`, `tag_picker_screen.dart`）到 `motionEntrance`，并保证在 Reduce Motion 下降级处理 — 状态：已完成（两者页面主体已用 `motionEntrance` 包裹）。
- 完善：删除/撤销退场动画、完成态局部微反馈、录音按钮脉冲、播放控件进度过渡 — 状态：规划中。
 - 完善：删除/撤销退场动画、完成态局部微反馈、录音按钮脉冲、播放控件进度过渡 — 状态：部分完成（录音按钮脉冲已实现；播放控件过渡正在进行）。
- 视觉回归与性能验证（尤其在低端设备上） — 状态：未开始。


## 四、约定（必须遵守）
- 本文件为动画迁移的权威进度记录：每次涉及动画的代码变更（新增/修改/回退），开发者/PR 必须同时更新本文件相应条目。
- 以 `lib/utils/motion.dart` 中的 `MotionTokens` 与 `motionEntrance` 为首选入口，避免在同一组件内混用多套动画机制。
- Reduce Motion 检测应通过 `motionAllowed(context)` 统一判断，且在禁用动画时降级为静态或极短淡入。


## 五、备注
- 若需要我帮忙把剩余待办逐条实现（例如先把 `home_screen` 的弹层迁移），请指示优先级，我会按此文件更新并提交修改。
- 本次已实现的改动已通过静态分析验证；运行时视觉验证建议在本地设备或模拟器上检视。


---
最后更新：2026-05-29（录音按钮脉冲已实现；播放控件过渡已添加小幅动画）
