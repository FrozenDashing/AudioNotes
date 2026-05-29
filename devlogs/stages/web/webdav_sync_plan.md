# Todo App WebDAV 同步落地方案 (基于 webdav_client)

## 1. 项目目标

- 多设备同步 Todo 数据
- 支持离线优先
- 数据加密（可选）
- 自动与手动同步
- 冲突检测与处理
- 后续可扩展音频附件同步

> SQLite 保持主存储，WebDAV 仅作为同步通道

---

## 2. MVP 同步范围

| 类型       | 同步 | 备注                     |
| ---------- | ---- | ------------------------ |
| Todo       | ✅    | 主任务数据               |
| Category   | ✅    | 分类                     |
| Tag        | ✅    | 标签                     |
| Reminder   | ✅    | 提醒                     |
| Audio      | ❌    | 后续可选                 |
| Settings   | 部分 | 仅同步通用设置           |

---

## 3. 文件结构（WebDAV）

```
/webdav-root/
 ├─ manifest.json        # 文件 hash、版本、最后同步时间
 ├─ todos.json
 ├─ categories.json
 ├─ tags.json
 └─ reminders.json
 attachments/             # 可选音频附件目录
```

---

## 4. Flutter 项目目录结构建议

```
lib/
 ├─ data/
 │   └─ todo_repository.dart
 ├─ models/
 │   └─ todo_sync_dto.dart
 ├─ sync/
 │   ├─ client/
 │   │   └─ webdav_client.dart       # 封装 webdav_client
 │   ├─ remote/
 │   │   └─ webdav_remote_store.dart # 远端文件映射
 │   ├─ planner/
 │   │   └─ sync_planner.dart        # 决策与冲突策略
 │   ├─ coordinator/
 │   │   └─ sync_coordinator.dart    # 执行同步任务
 │   ├─ serializer/
 │   │   └─ todo_serializer.dart
 │   ├─ encryption/
 │   │   └─ encryption_service.dart
 │   └─ providers/
 │       └─ sync_provider.dart       # Riverpod 状态管理
 ├─ providers/
 │   └─ settings_provider.dart
 └─ screens/
     └─ settings/
         └─ webdav_settings_screen.dart
```

---

## 5. 数据序列化

### TodoSyncDto 示例

```dart
class TodoSyncDto {
  String id;
  String title;
  bool completed;
  List<String> tags;
  int orderIndex;
  DateTime updatedAt;
  DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'tags': tags,
    'orderIndex': orderIndex,
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  static TodoSyncDto fromJson(Map<String, dynamic> json) => TodoSyncDto(
    id: json['id'],
    title: json['title'],
    completed: json['completed'],
    tags: List<String>.from(json['tags']),
    orderIndex: json['orderIndex'],
    updatedAt: DateTime.parse(json['updatedAt']),
    deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
  );
}
```

- 本地 `TodoItem` → `TodoSyncDto` → JSON → 上传
- 下载 JSON → `TodoSyncDto` → 本地数据库

---

## 6. WebDAV Client 封装

### `lib/sync/client/webdav_client.dart`

```dart
import 'package:webdav_client/webdav_client.dart';

class WebDavClientWrapper {
  final Client client;

  WebDavClientWrapper(String baseUrl, String username, String password)
      : client = Client(
          baseUrl: baseUrl,
          user: username,
          password: password,
        );

  Future<void> uploadFile(String remotePath, String content) async {
    await client.write(remotePath, content.codeUnits);
  }

  Future<String> downloadFile(String remotePath) async {
    final bytes = await client.read(remotePath);
    return String.fromCharCodes(bytes);
  }

  Future<List<String>> listDirectory(String remoteDir) async {
    final list = await client.readDir(remoteDir);
    return list.map((e) => e.path).toList();
  }

  Future<void> deleteFile(String remotePath) async {
    await client.remove(remotePath);
  }
}
```

---

## 7. Remote Store

`webdav_remote_store.dart` 负责将 WebDAV 文件映射到 DTO：

```dart
class WebDavRemoteStore {
  final WebDavClientWrapper client;

  WebDavRemoteStore(this.client);

  Future<Map<String, TodoSyncDto>> loadTodos() async {
    final content = await client.downloadFile('/todos.json');
    final List jsonList = jsonDecode(content);
    return {for (var e in jsonList) e['id']: TodoSyncDto.fromJson(e)};
  }

  Future<void> saveTodos(Map<String, TodoSyncDto> todos) async {
    final content = jsonEncode(todos.values.map((e) => e.toJson()).toList());
    await client.uploadFile('/todos.json', content);
  }
}
```

---

## 8. Sync Planner

- 输入：local state, remote state, baseline state
- 输出：Upload / Download / Merge / Conflict
- 冲突策略：

```dart
enum ConflictStrategy { localWins, remoteWins, latestModified, manual }
```

- 三方比较：
  1. 单边修改 → 单向同步
  2. 双方不同字段修改 → 字段级合并
  3. 双方同字段修改 → 根据策略选择

---

## 9. Sync Coordinator

- 执行 Planner 决策
- 更新 SQLite
- 更新 sync_records / sync_jobs
- 错误重试

```dart
Future<void> syncNow({bool manual = false});
Future<void> schedulePeriodicSync();
Future<void> syncOnStartup();
```

- 单任务锁 + 防抖处理

---

## 10. 安全措施

- 凭据存储：`flutter_secure_storage`
- 传输：HTTPS
- 内容加密（可选）

```dart
final key = Key.fromUtf8('32charslongsecretkey!!!1234567');
final iv = IV.fromLength(16);
final encrypter = Encrypter(AES(key));
String encryptData(String plain) => encrypter.encrypt(plain, iv: iv).base64;
String decryptData(String enc) => encrypter.decrypt64(enc, iv: iv);
```

- 大文件附件 → 分块上传 / 下载

---

## 11. 数据库改造

- 新增表：

```text
sync_records(entityId, entityType, baselineHash, remoteHash, lastSyncedAt)
sync_jobs(entityId, entityType, operation, dirtyAt, retryCount)
```

- 业务表保持 SQLite 原有结构

---

## 12. UI / Settings

- WebDAV 设置页：
  - URL
  - 用户名/密码
  - 自动同步开关
  - 启动延迟
  - 同步间隔
  - 冲突策略
- 测试连接按钮 → 调用 `WebDavClientWrapper` 的 `listDirectory` 或 `read` 测试

---

## 13. 开发顺序

1. Settings + 测试连接
2. 数据库同步表
3. DTO / JSON 序列化
4. WebDAV Client 封装
5. Remote Store
6. Sync Planner（冲突策略）
7. Sync Coordinator（执行同步）
8. UI（同步开关、状态显示）
9. 自动同步策略（启动 / 定时 / 恢复）
10. 可选：加密 & 附件同步

---

这份方案覆盖 webdav_client 接口 + 自定义同步引擎 + DTO + 冲突处理 + UI，适合现有 Todo App 并能后续扩展音频同步。

