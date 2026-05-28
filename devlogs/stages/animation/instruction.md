本档为应用内关键组件与用户操作的动画规范与实现建议。目标是：
- 提升界面连贯性（motion continuity）与可理解性（motion meaning）。
- 在不牺牲性能的前提下，使用 Flutter 推荐的隐式/显式动画组件实现平滑、可取消的交互动画。
- 对于开启“减少动画（Reduce Motion）”的用户，提供可降级的无动画替代。

通用约定：
- 基本时长：短动作 150ms，标准动作 250ms，复杂/容器转换 350–450ms。
- 常用曲线：快速出（Curves.easeOutCubic），缓入出（Curves.easeInOut），物理感弹性（Curves.elasticOut，谨慎使用）。
- 层次原则：先动画尺寸/位置，再动画不透明度；避免同时对大量元素做昂贵布局动画，优先使用合成层（translate/opacity/scale）。
- 性能提示：对长列表使用 AnimatedList/SliverAnimatedList，拖拽使用 ReorderableListView 内置的拖拽动画，持久化/DB 更新应在动画结束或可并行时执行以避免卡顿视觉反转。

无障碍：
- 在 MediaQuery.of(context).disableAnimations 或 platform accessibility 设置开启“减少动画”时，跳过非必要动画或将时长设置为 0。

下面逐项列出组件/操作与对应动画细节：

**Todo 列表（列表项/分组）**
- 场景：列表项（单条待办）新增、删除、完成、优先级更改、分组展开/折叠、拖拽重排。
- 动画目的：让列表变动有方向感，避免因持久化延迟产生“回弹”错觉。
- 新增（插入到顶部或指定索引）：使用 AnimatedList.insertItem()
	- 时长：250ms，曲线：easeOutCubic。
	- 动画组合：从上方轻微移动（translateY -8..0px）+ 透明度 0→1 + 轻微 scale 0.98→1.0。
	- Widget：使用 SizeTransition（包裹高度展开）配合 FadeTransition。
- 删除（移出）：使用 AnimatedList.removeItem()
	- 时长：200ms，曲线：easeInCubic。
	- 动画组合：向下或向上滑出（与用户删除方向一致）+ fade out + 高度收缩（SizeTransition）。
	- 行为：在移除动画进行时，先从内存/内核移除 UI 元素显示，DB 删除在动画开始或结束时并行触发（建议并行以减少感知延迟），但若删除失败需显示撤销 SnackBar 并回插动画。
- 标记为完成（toggle 完成态）：
	- 时长：220ms，曲线：easeInOut。
	- 动画组合：条目背景/文本颜色淡入变更（AnimatedContainer 动画 color），勾选图标使用 ScaleTransition（从 0.6→1.0）+轻微弹性，随后条目在“已完成”聚合到分组顶部/底部时使用 AnimatedList 的移动动画（SliverAnimatedList/implicit reorder）。
	- 聚合逻辑：将移动与 fade/slide 混合，先做视觉上的勾选确认，再做条目移动（避免同时做两个冲突动画）。
- 拖拽重排（ReorderableListView 内）：
	- 内置拖拽：使用 ReorderableListView 的默认拖拽手柄与悬浮视觉；自定义时确保拖拽项使用 Material 的 elevation（如 6）与缩放（scale 1.03）以突出悬浮感。
	- 拖拽过程中：被拖拽项使用 LongPressDraggable 的 feedback 是一个半透明的卡片（opacity 0.92）并带有轻微缩放；占位项使用 SizeTransition 平滑缩放以显示空位。
	- 释放与持久化：在用户释放后先执行本地列表 reorder 动画（短 150–200ms 的移动过渡），完成视觉落位后再写入 DB；若 DB 更新失败，展示撤销/错误提示并用反向动画回滚。

**分组折叠/展开（Group Header）**
- 场景：点击分组头（例如“今天/待办/已完成”）展开或收起该组。
- 动画目的：表现内容层次与展开的上下文关系。
- 实现建议：
	- 使用 AnimatedCrossFade 或 AnimatedSize 包裹内容区域以实现高度动画（时长 250–320ms，曲线 easeInOut）。
	- 同时对 header 的箭头图标使用 RotationTransition（从 0→180deg），并对 header 背景做轻微色彩（AnimatedContainer）或阴影变化以提升焦点感。

**新增/编辑 Todo 的表单（对话框/底板）**
- 场景：点击 FAB 或编辑按钮打开新增/编辑表单。
- 动画目的：保持视线连续（来源知觉）。
- 实现建议：
	- 小型表单（内嵌）使用 AnimatedSwitcher 切换并做 Fade + Slide (from bottom)（时长 200–260ms）。
	- 弹窗/底部表单使用 showModalBottomSheet 的内置弹出动画并自定义 shape 过渡：背景遮罩使用 FadeTransition，sheet 使用 SlideTransition(translateY 16..0) + elevation 渐进。
	- 若从列表项打开编辑，考虑使用 Hero（shared element）在条目缩略与表单头之间做视觉连接（Hero 标签以 todo id 命名）。

**设置页面导航（Settings Hub → 二级页面）**
- 场景：从设置入口进入: 外观、待办、语音三类二级页面。
- 动画目的：体现“层级”与“导航上下文”。
- 实现建议：
	- 使用标准的 MaterialPageRoute 转场，但采用右侧平移（desktop/web 环境）或自定义 Fade+Slide（mobile），时长 260ms。
	- 对于“Hub → 子页面”的转场使用 Shared Axis Transition（从 material motion 的 motion system）：容器 X/Y 方向的 Slide + Fade（时长 300ms，Curves.easeInOut）。
	- 回退时反向播放相同动画。

**主题/外观切换（浅色/深色/主题色）**
- 场景：用户切换主题或字体大小。
- 动画目的：平滑过渡配色与文字布局，避免突变。
- 实现建议：
	- 使用 AnimatedTheme 或 AnimatedBuilder 驱动 ThemeData 的渐变（时长 350–450ms，curve easeInOut）。
	- 字体/字号变化使用 AnimatedDefaultTextStyle 或 TextStyleTween，配合 LayoutBuilder/AnimatedSize 缓和布局跳动。
	- 对于关键页面，配合 FadeTransition 与颜色混合以避免瞬时对比过强。

**语音/模型选择与在线加载**
- 场景：在语音设置中选择模型、测试发音或下载模型包。
- 动画目的：反馈正在进行的网络/IO 操作，并在模型准备好时提供平滑切换。
- 实现建议：
	- 在点击开始加载时用小型 Progress Indicator（CircularProgressIndicator）替换操作按钮（使用 AnimatedSwitcher），并对按钮做 scale down→up 的反馈（时长 180ms）。
	- 完成后用 FadeTransition 替换为“就绪”状态，小提示使用 SnackBar + SlideTransition 从底部出现。

**媒体（录音/播放）控件**
- 场景：录音开始/停止、播放、进度更新。
- 动画目的：即时反馈录音/播放状态与能量感（音量指示）。
- 实现建议：
	- 录音时使用微交互动画：录音按钮的背景用 AnimatedContainer 在两个颜色之间淡入淡出（时长 600ms 循环，曲线 easeInOut），同时麦克风图标使用 Pulse（scale 1.0→1.06→1.0）做能量感。
	- 播放进度使用线性 ProgressBar，進度变化使用 AnimationController 驱动平滑过渡，不要直接 setState 造成跳动。
	- 暂停/播放切换用 Icon 的 AnimatedSwitcher（fade + scale）。

**全局层级动画与遮罩（Modal、Snackbar、Confirm）**
- 场景：确认对话框、撤销提示、全局错误提示。
- 实现建议：
	- 使用 Fade+Slide（from bottom）的 Snackbar 动画（默认 Material 行为足够），但对重要确认使用 Dialog 的 scale+fade（从 0.95→1.0, 180–220ms）。

**错误恢复与回滚动画**
- 场景：因为网络或 DB 操作失败需要回滚 UI 更改（如重排/删除失败）。
- 实现建议：
	- 在本地完成乐观更新动画后，如果操作失败，执行反向动画（mirror animation）以重建用户对状态变更的因果感。并在动画完成后显示错误提示与可撤销操作。

示例实现要点（Flutter 组件建议）
- 轻量级/布局动画：AnimatedContainer, AnimatedOpacity, AnimatedDefaultTextStyle, AnimatedSize。
- 列表与插入/删除：AnimatedList, SliverAnimatedList。
- 复杂显式控制：AnimationController + SlideTransition / ScaleTransition / FadeTransition / RotationTransition。
- 共享元素（页面内/跨页）：Hero（注意 tag 唯一性与避免过度使用）。
- 可组合的微交互：AnimatedSwitcher（切换图标/按钮），TweenAnimationBuilder（快速原型）。

测试与验证：
- 手工测试用例：
	1. 在开启/关闭“减少动画”情况下分别验证所有动画是否按预期降级。
	2. 拖拽改变条目顺序（向下/向上）多次，观察是否存在视觉回弹或顺序错位。
	3. 在数据库延迟或失败时，验证撤销动画能正确回滚并显示错误提示。
- 性能监测：在低端设备上使用 Flutter 性能剖析工具（Profile 模式）监测帧率，确保关键动画在 60fps 目标下运行平滑。

交付物（本次提交）:
- 在 devlogs/stages/animation/ 下更新的 instruction.md（本文件），包含每个关键组件/操作的动画规范与实现建议。

后续建议：
- 将每个动画点作为小任务分批实现（例如：“列表插入/删除动画实现并测试”），并为每项添加一个自动化 UI 测试用例或集成测试场景。

无障碍考虑：
- 尊重 MediaQuery.disableAnimations 并提供文本提示与语义广播作为替代。

风格令牌（推荐）
- Micro: 120ms, Curve: Curves.easeOutCubic
- Medium: 220ms, Curve: Curves.easeInOut
- Page: 320–450ms, Curve: Curves.decelerate

修订历史
- 2026-05-29: 初稿，覆盖主要交互与组件。

