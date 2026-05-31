# Audionote Todo Card 三档布局规划与代码指导

> 目标：解决竖屏窄宽度下，Todo 卡片右侧信息（优先级、提醒时间、标签等）增多后把左侧标题挤没的问题。  
> 方案：把当前“单一横排布局”重构成 **三档响应式布局**，并通过 `LayoutBuilder`、`Wrap`、`ConstrainedBox`、`Overflow` 策略，保证不同屏宽下都能优先保住标题可读性。

---

## 1. 问题本质

你现在的卡片大概率是：

- 左侧：标题区（`Expanded`）
- 右侧：状态区（标签、优先级、提醒、checkbox 等）

在竖屏窄宽度下，右侧信息越多，右侧区块越容易占满整行，导致左侧标题被压缩到几乎不可见。

这个问题**不能只靠调小字号**解决，因为它本质上是一个 **布局优先级问题**，不是字体问题。

正确方向是：

1. 给卡片做宽度分流；
2. 不同宽度下采用不同布局；
3. 在窄屏时主动减少信息密度；
4. 任何时候都优先保证标题区域可读。

---

## 2. 三档布局定义

建议把 `TodoItemCard` 分成三档：

### 2.1 Compact（紧凑档）
**触发条件**：卡片可用宽度很窄，例如 `maxWidth < 380`。

**展示目标**：只保留最关键的信息。

**建议内容**：
- 标题（必须保留）
- checkbox（必须保留）
- 最多 1～2 个最重要的元信息，例如一个优先级 + 一个提醒短标
- 标签不全展示，超出的折叠为 `+N`

**适用场景**：
- 竖屏窄设备
- 多个元信息同时存在
- 列表滚动较密集

**视觉策略**：
- 纵向堆叠或半堆叠
- 元信息在第二行
- 不让任何元信息抢走标题的首行空间

---

### 2.2 Standard（标准档）
**触发条件**：中等宽度，例如 `380 <= maxWidth < 520`。

**展示目标**：信息完整但不过度拥挤。

**建议内容**：
- 第一行：标题 + checkbox
- 第二行：优先级、提醒时间、标签摘要
- 标签可以采用 `Wrap`，但要限制最大条数
- 右侧信息允许存在，但不允许压缩标题

**适用场景**：
- 普通竖屏
- 中等宽度列表
- 信息较多但还未到“平板式展开”

---

### 2.3 Expanded（展开档）
**触发条件**：宽度较大，例如 `maxWidth >= 520`，或者横屏。

**展示目标**：更完整地展示元信息。

**建议内容**：
- 标题区保持第一视觉优先级
- 元信息可以放在右侧,所有元素在一行
- 标签可展示更多，但依旧保持上限
- 优先级、提醒、截止时间可并排显示

**适用场景**：
- 横屏
- 平板
- 桌面窗口宽度较大

---

## 3. 布局核心原则

### 3.1 标题永远优先
标题区不能再和所有元信息“抢宽度”。

建议做法：
- 标题区放在 `Expanded`，但只让它和“右侧固定宽度区”竞争，而不是和无限增长的 `Wrap` 竞争。
- 标题区尽量保持一行，最多两行。
- 标题右侧如果有 checkbox，优先固定 checkbox 宽度，而不是让 checkbox 去挤压标题。

### 3.2 右侧元信息要有上限
右侧不要是“想显示多少就显示多少”的自由布局。

建议做法：
- 用 `ConstrainedBox(maxWidth: xxx)` 限制元信息区最大宽度
- 或者在窄屏时直接移动到第二行
- 标签行要做数量上限，例如只显示前 2～3 个标签，其余折叠成 `+N`

### 3.3 信息优先级要明确
信息排序建议是：

1. 标题
2. 完成状态 checkbox
3. 重要优先级
4. 提醒 / 截止时间
5. 标签
6. 其他低优先级元信息

### 3.4 小屏主动降级
不要在小屏强塞所有信息。

建议降级策略：
- 标签只展示前 N 个
- 提醒时间只展示短格式
- 优先级只展示图标或短词
- 低优先级信息统一折叠

---

## 4. 推荐的代码结构

建议把 `TodoItemCard` 拆成以下几个小块：

- `TodoCardHeader`：标题 + checkbox
- `TodoCardMetaRow`：优先级 / 提醒 / 截止时间
- `TodoCardTagRow`：标签摘要
- `TodoCardCompactMeta`：紧凑模式下的摘要行
- `TodoCardActions`：操作按钮（如有）

这样好处是：
- 后续动画更容易加
- 三档布局切换时，不用重写全部卡片
- 每个小块都可以独立做局部刷新

---

## 5. 推荐实现方案：`LayoutBuilder` 分档

### 5.1 宽度断点建议

建议先用这三个断点：

- `compact`: `< 380`
- `standard`: `380 ~ 520`
- `expanded`: `>= 520`

如果你的列表区域经常在侧边栏、分屏、桌面窗口里出现，可以后续把断点微调成：

- `compact`: `< 360`
- `standard`: `360 ~ 560`
- `expanded`: `>= 560`

### 5.2 基本骨架

```dart
class TodoItemCard extends StatelessWidget {
  final TodoItem todo;
  final bool showCategoryChip;
  final bool compact;
  final bool subdued;

  const TodoItemCard({
    super.key,
    required this.todo,
    this.showCategoryChip = true,
    this.compact = false,
    this.subdued = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 380) {
          return _buildCompactLayout(context);
        }

        if (width < 520) {
          return _buildStandardLayout(context);
        }

        return _buildExpandedLayout(context);
      },
    );
  }
}
```

---

## 6. 三档布局的实现指导

### 6.1 Compact 布局

**目标**：把标题和 checkbox 保住，把其他信息压缩成一行摘要。

#### 结构建议

```dart
Widget _buildCompactLayout(BuildContext context) {
  final title = _buildTitle(context, maxLines: 2);
  final meta = _buildCompactMeta(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: 8),
          _buildCheckbox(context),
        ],
      ),
      if (meta != null) ...[
        const SizedBox(height: 6),
        meta,
      ],
    ],
  );
}
```

#### 紧凑模式建议
- 标题最多 2 行
- checkbox 固定在右侧
- meta 行只显示最重要的 1～2 项
- 标签过多时显示 `+N`
- 提醒时间做短格式，如 `09:30`

#### 适合的 meta 例子
- `高优先级`
- `09:30`
- `+3`

---

### 6.2 Standard 布局

**目标**：保留较完整信息，但标题必须优先。

#### 结构建议

```dart
Widget _buildStandardLayout(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTitle(context, maxLines: 1)),
          const SizedBox(width: 8),
          _buildCheckbox(context),
        ],
      ),
      const SizedBox(height: 6),
      _buildMetaRow(context, maxItems: 3, compact: false),
    ],
  );
}
```

#### Standard 模式建议
- 标题 1 行,tickbox同行固定在最右边
- 元信息放第二行
- 标签显示前 2～3 个
- 提醒 / 截止时间可以并排
- 元信息仍然允许换行，但不要撑得太高

---

### 6.3 Expanded 布局

**目标**：空间足够时，把信息显示得更完整，但仍保持整洁。

#### 结构建议

```dart
Widget _buildExpandedLayout(BuildContext context) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(context, maxLines: 2),
            if (showCategoryChip) ...[
              const SizedBox(height: 6),
              _buildCategoryChip(context),
            ],
          ],
        ),
      ),
      const SizedBox(width: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildMetaRow(context, maxItems: 5, compact: false),
            const SizedBox(height: 6),
            _buildCheckbox(context),
          ],
        ),
      ),
    ],
  );
}
```

#### Expanded 模式建议
- 元信息可更完整,所有元素在一行
- 仍要限制右侧最大宽度
- 不要让标签无限增长
- 如果元信息太多，继续保持“摘要 + 折叠”策略

---

## 7. 元信息区的正确做法

你现在的问题本质上在于：右侧元信息没有上限，所以它会把标题挤掉。

### 7.1 推荐做法：元信息统一汇总
把优先级、提醒、标签统一交给一个元信息构建器：

```dart
Widget _buildMetaRow(
  BuildContext context, {
  required int maxItems,
  required bool compact,
}) {
  final chips = <Widget>[];

  if (todo.priority != TodoPriority.normal) {
    chips.add(_priorityChip(todo.priority));
  }

  if (todo.remindAt != null) {
    chips.add(_timeChip(todo.remindAt!, compact: compact));
  }

  if (todo.dueAt != null) {
    chips.add(_dueChip(todo.dueAt!, compact: compact));
  }

  for (final tag in todo.tags.take(maxItems)) {
    chips.add(_tagChip(tag));
  }

  final overflowCount = todo.tags.length - maxItems;
  if (overflowCount > 0) {
    chips.add(_overflowChip(overflowCount));
  }

  return Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.end,
    children: chips,
  );
}
```

### 7.2 关键点
- `Wrap` 可以换行，但必须有限制
- `maxItems` 必须存在
- 如果太多，要折叠成 `+N`
- 不要把所有标签都原样展开

---

## 8. 文字显示策略

### 8.1 标题处理
标题建议用：
- `maxLines: 1`（标准 / expanded）
- `maxLines: 2`（compact）
- `TextOverflow.ellipsis`

### 8.2 元信息处理
元信息建议用短语态：
- `高`
- `中`
- `低`
- `09:30`
- `+2`

不要把长文案放进卡片内部作为“固定展示文本”。

### 8.3 标签处理
标签只展示摘要：
- 优先显示最近或最重要的标签
- 最多显示 2～3 个
- 其余折叠

---

## 9. 样式层建议

### 9.1 卡片外观
为了减少拥挤感，建议：
- 圆角保持统一
- 阴影轻一点
- 不要用过重背景纹理
- 元信息用轻量 chip

### 9.2 信息层级
颜色建议分层：
- 标题：最高对比度
- 主要元信息：中等对比度
- 次要元信息：低对比度

### 9.3 间距建议
- 标题与元信息之间：6～8dp
- chip 之间：4～6dp
- 卡片左右内边距：12～16dp
- 卡片上下内边距：10～14dp

---

## 10. 推荐的落地步骤

### 第一步：抽 LayoutBuilder
先把 `TodoItemCard` 的最外层改成 `LayoutBuilder`，只做宽度分档，不改内部样式。

### 第二步：保住标题
把标题区单独抽成 `TodoCardHeader`，先确保标题不再被压没。

### 第三步：限制右侧元信息宽度
给右侧区块加 `ConstrainedBox` 或移动到第二行。

### 第四步：做紧凑版 meta 摘要
新增 `compact` 模式，只显示最重要信息。

### 第五步：再做 expanded 版精修
在宽屏下把元信息摆得更完整，但继续保留上限。

---

## 11. 代码落点建议

建议优先修改这些位置：

### `lib/widgets/todo_item_card.dart`
- 加 `LayoutBuilder`
- 拆 `_buildCompactLayout` / `_buildStandardLayout` / `_buildExpandedLayout`
- 统一标题、checkbox、元信息的分层

### `lib/widgets/completed_text.dart`
- 如果完成态样式会挤压标题，建议改成独立 chip 或小文本，不要占用主布局宽度

### `lib/widgets/todo_group_section.dart`
- 组头和列表壳不要再给 item 卡片额外压缩宽度

### `lib/screens/home_screen.dart`
- 确保列表容器本身不再过度限制 item 宽度

---

## 12. 一个可直接照着做的判断规则

你可以把 `TodoItemCard` 的布局决策写成这样的规则：

- `< 380`：标题 2 行，元信息第二行，标签折叠
- `380 ~ 520`：标题 1 行，元信息第二行，标签摘要
- `>= 520`：标题左，元信息右，展示更完整

这个规则简单、稳定，适合你的项目。

---

## 13. 推荐的验收标准

完成后应该满足：

1. 竖屏窄宽度下，标题不会被右侧元信息挤没。
2. 标签、优先级、提醒时间增多时，卡片会自动降级布局。
3. 横屏或宽屏下，卡片仍能展示较完整信息。
4. 小屏不会出现文字溢出、遮挡、布局跳动。
5. 后续再新增更多元信息时，只需要给 meta 摘要逻辑加字段，不需要重写卡片。

---

## 14. 最后建议

这个问题最稳的解法，不是“更小的字”，而是：

- **分档布局**
- **标题优先**
- **元信息限宽**
- **标签摘要化**
- **窄屏主动降级**

这样你的 Todo 卡片在竖屏、横屏、分屏、桌面窗口下都会更稳，也为后续动画和局部刷新留出干净的结构边界。

