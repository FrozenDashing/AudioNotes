可以，按你现在这套结构，最稳的做法是把“删除”拆成两层：**软删除进入垃圾桶**，**垃圾桶里再做永久清理**。这样既保留撤销能力，又不会破坏你现有的提醒、同步、排序和音频文件体系。

你这份代码里有一个很好的基础：`todo_item` 表已经有 `deleted_at` 字段了，但现在 `TodoRepository.deleteTodo()` 仍然是**直接 `db.delete()` 硬删**，而且 `TodoListNotifier.deleteTodo()` 也是直接调用它，所以第一步不是加新表，而是把删除语义改掉。

## 1）先把删除分成“软删除”和“永久删除”

建议在 `lib/data/todo_repository.dart` 里拆成三个动作：

```dart
Future<void> softDeleteTodo(String id);
Future<void> restoreTodo(String id);
Future<void> purgeTodoPermanently(String id);
```

### 软删除

软删除时不要删数据库行，只做这些事：

* `deleted_at = DateTime.now().millisecondsSinceEpoch`
* `updated_at = now`
* 取消提醒：`ReminderService.clearReminder(todoId)` 或等价逻辑
* 如果以后接系统日历同步，也要顺手删除 calendar event
* 保留 `text / dueAt / remindAt / audioPath / tags / category / orderIndex`，方便恢复

### 永久删除

永久删除才是真正清理：

* 删除 `todo_item` 行
* 删除 `reminders` 行
* 删除 `todo_tags` 关联
* 删除 `sync_records / sync_jobs` 里这个 todo 的记录
* 取消通知 / 日历事件
* 从内存态 provider 里移除

你现在的 `deleteTodo()` 里已经有“删音频 + 删数据库”的逻辑，可以把它改名成 `purgeTodoPermanently()`，把原来的 `deleteTodo()` 变成软删除入口。

---

## 2）查询层要统一把“已删除”隔离开

这是最关键的一点。你现在的 `DatabaseHelper.getTodos()` 没有过滤 `deleted_at`，所以一旦改成软删除，垃圾桶里的数据会继续出现在主界面。

建议这样改：

```dart
Future<List<TodoItem>> getTodos(
  TodoQueryOptions options, {
  bool includeDeleted = false,
}) async
```

默认情况下：

* 主界面：`deleted_at IS NULL`
* 垃圾桶：`deleted_at IS NOT NULL`
* 彻底清理：不走查询，走 `purge` 方法

同时把这些查询也统一检查一下：

* `getAllTodos()`
* `getTodoById()`
* `getTodosByCategory()`
* `getTodosByTag()`

你现在 `getTodosByCategory()` 和 `getTodosByTag()` 已经有 `deleted_at IS NULL`，这很好，主列表只需要把 `getTodos()` 也补上同样规则。

---

## 3）垃圾桶最好单独做一个 notifier / provider

不要把垃圾桶逻辑硬塞进现有 `TodoListNotifier`，会把主列表和回收站状态搅在一起。更干净的做法是新增：

* `TrashTodosNotifier`
* `trashTodosProvider`

它只负责三件事：

* `loadTrash()`
* `restoreTodo(id)`
* `purgeAllTrash()`

大概像这样：

```dart
class TrashTodosNotifier extends AsyncNotifier<List<TodoItem>> {
  late final TodoRepository _repository;

  @override
  Future<List<TodoItem>> build() async {
    _repository = ref.read(todoRepositoryProvider);
    return _repository.getDeletedTodos();
  }

  Future<void> loadTrash() async {
    state = AsyncValue.data(await _repository.getDeletedTodos());
  }

  Future<void> restoreTodo(String id) async {
    await _repository.restoreTodo(id);
    await loadTrash();
    ref.read(todoListProvider.notifier).loadTodos();
  }

  Future<void> purgeAllTrash() async {
    await _repository.purgeAllDeletedTodos();
    await loadTrash();
    ref.read(todoListProvider.notifier).loadTodos();
  }
}
```

这样主列表和垃圾桶各管各的，状态更稳定。

---

## 4）垃圾桶界面怎么做最合适

你描述的交互非常清晰，推荐做成一个单独页面：`TrashScreen`。

### 入口

在主界面右上角的更多菜单里加一个项：

* 图标：垃圾桶
* 文案：垃圾桶 / 回收站

点击后 push 到 `TrashScreen`

### 页面布局

`TrashScreen` 的结构可以很简单：

* `AppBar`

  * 标题：垃圾桶
  * 右上角：`清除` 按钮
* `ListView`

  * 每个 item 只显示：

    * 左侧：todo text
    * 右侧：`3天前删除` / `2小时前删除`
  * 点击整条只弹出一个操作：

    * `恢复`

### tile 样式

你说“和主界面 tile 渲染类似”，这个建议保留主视觉，但裁掉复杂信息：

* 保留圆角、卡片、轻微阴影、动画
* 去掉优先级、标签、截止时间、提醒时间、完成状态
* 只保留标题 + 删除时间
* 右侧用一个淡色小字或 chip 显示“距删除时间”

如果你想复用现有结构，建议新增一个轻量组件，比如：

* `TrashTodoItemCard`
* 或者给现有 `TodoItemCard` 加一个 `mode: TodoTileMode.active / trash`

但从可维护性看，**单独新建一个 trash tile 更干净**。

### 点击后的交互

点击后不要直接恢复，建议底部弹一个很轻的操作面板：

* `恢复`
* `取消`

这样和主界面的“更多操作”风格一致。

---

## 5）“清除”按钮怎么做才安全

右上角的 `清除` 按钮建议做成一次性永久删除，不要做撤销。

点击后弹确认框：

* 标题：清空垃圾桶？
* 文案：此操作会永久删除所有已删除的代办，无法恢复。
* 按钮：取消 / 清空

执行时走事务或批处理，避免删到一半状态错乱。

---

## 6）自动清理间隔怎么加

这个设置很适合放在 `todo settings` 里，因为它和任务生命周期直接相关。

### 新增一个枚举

在 `lib/models/settings_state.dart` 里加：

```dart
enum TrashAutoPurgeInterval {
  oneDay,
  threeDays,
  sevenDays,
  thirtyDays,
  never,
}
```

然后在 `SettingsState` 里加字段：

```dart
final TrashAutoPurgeInterval trashAutoPurgeInterval;
```

默认值建议是：

* `sevenDays` 或 `never`

如果你希望偏安全，默认 `never`；
如果你希望偏自动化，默认 `7天`。

### 设置界面

在 `lib/screens/settings/todo_settings_screen.dart` 里加一个新的 `SectionCard`：

标题可以叫：

* `代办被删除后自动被清理的间隔`

选项就是你说的这几个：

* 1天
* 3天
* 7天
* 30天
* 永不

### 持久化

同步改 `lib/repositories/settings_repository.dart`：

* 新增 key
* `loadSettings()` 读出来
* `saveSettings()` 写进去

---

## 7）自动清理服务怎么跑最合理

这里不要只靠定时器，因为 Flutter App 在后台时不可靠。更稳的是做一个 `TrashCleanupService`，在这些时机触发：

1. App 启动后
2. App 回到前台时
3. 用户修改自动清理间隔后
4. 用户手动点“清除”时

逻辑很简单：

```dart
Future<void> purgeExpiredTrash() async {
  final interval = settings.trashAutoPurgeInterval;
  if (interval == TrashAutoPurgeInterval.never) return;

  final cutoff = DateTime.now().subtract(_toDuration(interval));
  final oldTrash = await repository.getDeletedTodos(olderThan: cutoff);

  for (final todo in oldTrash) {
    await repository.purgeTodoPermanently(todo.id);
  }
}
```

这样就算用户不打开垃圾桶，旧数据也会在合适的时机被清掉。

---

## 8）恢复时要注意什么

恢复不是简单把 `deleted_at` 清空就完了，最好再做两件事：

* 如果这个 todo 原本有 `remindAt`，恢复后重新调一次 `scheduleReminderForTodo(todo)`
* 如果未来加入系统日历同步，也要重新创建日历事件

也就是说，恢复后要把它当成“重新激活的 todo”来处理，而不是单纯改一列字段。

---

## 9）你这个项目里最容易漏掉的地方

有几个点要特别注意：

* `TodoListNotifier.deleteTodo()` 不能再直接硬删，要改成软删除
* 主列表查询必须统一排除 `deleted_at != null`
* 垃圾桶恢复后要刷新主列表
* 永久删除要处理音频文件，否则会留下孤儿文件
* 如果同步系统已经存在，软删除本身要作为同步事件，而不是等永久删除才同步
* `reminders` 表不会因为软删除自动 cascade，所以软删除时要显式清理提醒记录

---

## 10）最推荐的落地顺序

我会按这个顺序做：

1. 先改 `TodoRepository`：软删 / 恢复 / 永久删
2. 再改 `getTodos()`：默认过滤 `deleted_at IS NULL`
3. 新增 `TrashTodosNotifier`
4. 新增 `TrashScreen`
5. 主界面更多菜单加“垃圾桶”
6. 设置里加“自动清理间隔”
7. 最后补 `TrashCleanupService`

这样不会把现有主列表搞乱，改动也最可控。

如果你要，我下一步可以直接按你这个项目的目录结构，把“要改哪些文件、每个文件加什么方法、页面怎么接路由”整理成一份可执行的开发清单。
