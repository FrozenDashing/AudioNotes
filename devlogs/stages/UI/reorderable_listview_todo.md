# Audionote APP: ReorderableListView 拖放重构方案（组内拖拽）

## 1. 重构目标

1. 使用 `ReorderableListView` 实现 **同组内拖拽**，支持调整待办顺序。
2. 保留 Repository、UI 同步和数据持久化逻辑。
3. 保证新接手的 AI 或开发者能准确理解并修改。

---

## 2. 数据模型与服务

### 2.1 数据模型
```dart
class TodoItem {
  final String id;
  final String title;
  String groupId; // 分组标识，例如 'incomplete', 'complete'
  bool isCompleted;

  TodoItem({required this.id, required this.title, required this.groupId, this.isCompleted = false});
}

class TodoGroup {
  final String id;
  final String name;
  List<TodoItem> items;

  TodoGroup({required this.id, required this.name, required this.items});
}
```

### 2.2 Repository 接口
```dart
class TodoRepository {
  Future<void> reorderItem({
    required String itemId,
    required int newIndex,
    required String groupId,
  });

  Future<void> deleteItem({required String itemId});
}
```

---

## 3. UI 组件设计

### 3.1 组内拖拽
```dart
class TodoGroupSection extends StatefulWidget {
  final TodoGroup group;
  final TodoRepository repository;

  const TodoGroupSection({super.key, required this.group, required this.repository});

  @override
  _TodoGroupSectionState createState() => _TodoGroupSectionState();
}

class _TodoGroupSectionState extends State<TodoGroupSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.group.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: widget.group.items.length,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = widget.group.items.removeAt(oldIndex);
            widget.group.items.insert(newIndex, item);
            widget.repository.reorderItem(
              itemId: item.id,
              newIndex: newIndex,
              groupId: widget.group.id,
            );
            setState(() {});
          },
          itemBuilder: (context, index) {
            final item = widget.group.items[index];
            return LongPressDraggable<TodoItem>(
              key: ValueKey(item.id),
              data: item,
              feedback: Material(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: EdgeInsets.all(8),
                  color: Colors.blueAccent.withOpacity(0.8),
                  child: Text(item.title, style: TextStyle(color: Colors.white)),
                ),
              ),
              child: TodoItemCard(item: item),
            );
          },
        ),
      ],
    );
  }
}
```

> 注意：此方案仅实现组内拖拽，不包含跨组拖拽逻辑。

---

## 4. 执行方案

1. **准备数据**：每个 `TodoGroup` 维护 `items` 列表。
2. **组内拖拽**：使用 `ReorderableListView.builder` + `onReorder` 调用 Repository 更新顺序。
3. **UI同步**：拖放结束后调用 `setState()` 更新列表。
4. **删除操作**：仍可以通过按钮或滑动删除触发 `repository.deleteItem`。
5. **状态管理**：确保与 Provider 或 StateNotifier 同步。
6. **测试**：
   - 单组拖拽顺序正确。
   - 删除功能生效。
7. **异常处理**：拖拽异常可回滚原顺序。

---

## 5. 开发注意事项

- 使用 `ReorderableListView.builder` 而非 `children:`，保证性能。
- `LongPressDraggable` 包裹每个 `TodoItemCard` 提供拖拽反馈。
- 保证 Repository 与 UI 完全同步，避免数据丢失。
- 可扩展：后续再增加跨组拖拽和特殊删除区域。