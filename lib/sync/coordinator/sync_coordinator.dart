import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../data/database_helper.dart';
import '../../models/todo_item.dart';
import '../../models/category.dart';
import '../../models/tag.dart';
import '../client/webdav_client_wrapper.dart';
import '../remote/webdav_remote_store.dart';
import '../serializer/todo_sync_dto.dart';
import '../serializer/sync_serializer.dart';
import '../planner/sync_planner.dart';

/// Current sync status for UI display
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  conflict,
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final int deleted;
  final String? errorMessage;
  final Duration? duration;

  const SyncResult({
    required this.success,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.deleted = 0,
    this.errorMessage,
    this.duration,
  });

  String get summary =>
      'Synced in ${duration?.inMilliseconds ?? '?'}ms: ↑$uploaded ↓$downloaded ⚡$conflicts 🗑$deleted';
}

/// Coordinates the full sync process: load data, plan, execute, and update.
class SyncCoordinator {
  final WebDavClientWrapper _clientWrapper;
  final WebDavRemoteStore _remoteStore;
  final SyncPlanner _planner;
  final SyncSerializer _serializer;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  String? _lastError;
  String? get lastError => _lastError;

  SyncResult? _lastResult;
  SyncResult? get lastResult => _lastResult;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  ConflictStrategy _conflictStrategy = ConflictStrategy.latestModified;
  ConflictStrategy get conflictStrategy => _conflictStrategy;

  void setConflictStrategy(ConflictStrategy strategy) {
    _conflictStrategy = strategy;
    // Also update planner's default strategy
    _planner.setDefaultStrategy(strategy);
  }

  SyncCoordinator({
    required WebDavClientWrapper clientWrapper,
    ConflictStrategy conflictStrategy = ConflictStrategy.latestModified,
  })  : _clientWrapper = clientWrapper,
        _remoteStore = WebDavRemoteStore(clientWrapper),
        _planner = SyncPlanner(defaultStrategy: conflictStrategy),
        _serializer = SyncSerializer(),
        _conflictStrategy = conflictStrategy;

  /// Configure the WebDAV client
  void configure({
    required String baseUrl,
    required String username,
    required String password,
    String remoteDir = '/audionotes',
  }) {
    _clientWrapper.configure(
      baseUrl: baseUrl,
      username: username,
      password: password,
      remoteDir: remoteDir,
    );
  }

  /// Reset the WebDAV client
  void reset() {
    _clientWrapper.reset();
  }

  /// Test the WebDAV connection
  Future<bool> testConnection() async {
    return _clientWrapper.testConnection();
  }

  /// Execute a full sync: load local + remote → plan → apply
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return const SyncResult(
          success: false, errorMessage: 'Sync already in progress');
    }

    if (!_clientWrapper.isConfigured) {
      return const SyncResult(
          success: false, errorMessage: 'WebDAV not configured');
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Ensure remote directory
      await _remoteStore.ensureDir();

      // 2. Load local data
      final db = await DatabaseHelper.instance.database;
      final localData = await _loadLocalData(db);

      // 3. Load remote data
      final remoteTodos = await _remoteStore.loadTodos();
      final remoteCategories = await _remoteStore.loadCategories();
      final remoteTags = await _remoteStore.loadTags();
      final remoteReminders = await _remoteStore.loadReminders();

      // 4. Load baseline hashes from sync_records
      final baselineHashes = await _loadBaselineHashes(db);

      final shouldBootstrapFromRemote = _shouldBootstrapFromRemote(
        localData: localData,
        remoteTodos: remoteTodos,
        remoteCategories: remoteCategories,
        remoteTags: remoteTags,
        remoteReminders: remoteReminders,
      );

      if (shouldBootstrapFromRemote) {
        await _applyRemoteSnapshot(
          db,
          remoteTodos: remoteTodos,
          remoteCategories: remoteCategories,
          remoteTags: remoteTags,
          remoteReminders: remoteReminders,
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        await _updateBaselineHashes(
          db,
          mergedTodos: remoteTodos,
          mergedCategories: remoteCategories,
          mergedTags: remoteTags,
          mergedReminders: remoteReminders,
          timestamp: now,
        );

        final manifest = SyncManifest(
          lastSyncedAt: now,
          fileHashes: {
            'todos.json': _serializer.computeHash(
                _serializer.serializeTodos(remoteTodos.values.toList())),
            'categories.json': _serializer.computeHash(_serializer
                .serializeCategories(remoteCategories.values.toList())),
            'tags.json': _serializer.computeHash(
                _serializer.serializeTags(remoteTags.values.toList())),
            'reminders.json': _serializer.computeHash(_serializer
                .serializeReminders(remoteReminders.values.toList())),
          },
        );
        await _remoteStore.saveManifest(manifest);

        stopwatch.stop();
        _lastSyncTime = DateTime.now();
        _status = SyncStatus.success;

        _lastResult = SyncResult(
          success: true,
          uploaded: 0,
          downloaded: remoteTodos.length +
              remoteCategories.length +
              remoteTags.length +
              remoteReminders.length,
          conflicts: 0,
          deleted: 0,
          duration: stopwatch.elapsed,
        );

        return _lastResult!;
      }

      // 5. Compute local hashes (used for comparison, stored implicitly in local data)
      // 6. Compute remote hashes (used for comparison, stored implicitly in remote data)

      // 7. Plan sync for each entity type
      final todoPlan = _planner.planSync<TodoSyncDto>(
        local: localData.todos,
        remote: remoteTodos,
        baselineHashes: baselineHashes['todo'] ?? {},
        hashFn: (dto) => _serializer.computeHash(jsonEncode(dto.toJson())),
        entityType: 'todo',
        updatedAtFn: (dto) => dto.updatedAt,
        strategy: _conflictStrategy,
      );

      final categoryPlan = _planner.planSync<CategorySyncDto>(
        local: localData.categories,
        remote: remoteCategories,
        baselineHashes: baselineHashes['category'] ?? {},
        hashFn: (dto) => _serializer.computeHash(jsonEncode(dto.toJson())),
        entityType: 'category',
        strategy: _conflictStrategy,
      );

      final tagPlan = _planner.planSync<TagSyncDto>(
        local: localData.tags,
        remote: remoteTags,
        baselineHashes: baselineHashes['tag'] ?? {},
        hashFn: (dto) => _serializer.computeHash(jsonEncode(dto.toJson())),
        entityType: 'tag',
        strategy: _conflictStrategy,
      );

      final reminderPlan = _planner.planSync<ReminderSyncDto>(
        local: localData.reminders,
        remote: remoteReminders,
        baselineHashes: baselineHashes['reminder'] ?? {},
        hashFn: (dto) => _serializer.computeHash(jsonEncode(dto.toJson())),
        entityType: 'reminder',
        strategy: _conflictStrategy,
      );

      // 8. Execute planned actions
      int uploaded = 0;
      int downloaded = 0;
      int conflicts = 0;
      int deleted = 0;

      // Execute todo plan
      for (final item in todoPlan.items) {
        final result =
            await _executeTodoAction(db, item, localData.todos, remoteTodos);
        uploaded += result.$1;
        downloaded += result.$2;
        conflicts += result.$3;
        deleted += result.$4;
      }

      // Execute category plan
      for (final item in categoryPlan.items) {
        final result = await _executeCategoryAction(
            db, item, localData.categories, remoteCategories);
        uploaded += result.$1;
        downloaded += result.$2;
        deleted += result.$4;
      }

      // Execute tag plan
      for (final item in tagPlan.items) {
        final result =
            await _executeTagAction(db, item, localData.tags, remoteTags);
        uploaded += result.$1;
        downloaded += result.$2;
        deleted += result.$4;
      }

      // Execute reminder plan
      for (final item in reminderPlan.items) {
        final result = await _executeReminderAction(
            db, item, localData.reminders, remoteReminders);
        uploaded += result.$1;
        downloaded += result.$2;
        deleted += result.$4;
      }

      // 9. Upload merged data to remote (full-file replace strategy)
      final mergedTodos =
          await _mergeAfterSync(localData.todos, remoteTodos, todoPlan);
      final mergedCategories = await _mergeAfterSync(
          localData.categories, remoteCategories, categoryPlan);
      final mergedTags =
          await _mergeAfterSync(localData.tags, remoteTags, tagPlan);
      final mergedReminders = await _mergeAfterSync(
          localData.reminders, remoteReminders, reminderPlan);

      await _remoteStore.saveTodos(mergedTodos);
      await _remoteStore.saveCategories(mergedCategories);
      await _remoteStore.saveTags(mergedTags);
      await _remoteStore.saveReminders(mergedReminders);

      // 10. Update baseline hashes in sync_records
      final now = DateTime.now().millisecondsSinceEpoch;
      await _updateBaselineHashes(
        db,
        mergedTodos: mergedTodos,
        mergedCategories: mergedCategories,
        mergedTags: mergedTags,
        mergedReminders: mergedReminders,
        timestamp: now,
      );

      // 11. Save manifest
      final manifest = SyncManifest(
        lastSyncedAt: now,
        fileHashes: {
          'todos.json': _serializer.computeHash(
              _serializer.serializeTodos(mergedTodos.values.toList())),
          'categories.json': _serializer.computeHash(_serializer
              .serializeCategories(mergedCategories.values.toList())),
          'tags.json': _serializer.computeHash(
              _serializer.serializeTags(mergedTags.values.toList())),
          'reminders.json': _serializer.computeHash(
              _serializer.serializeReminders(mergedReminders.values.toList())),
        },
      );
      await _remoteStore.saveManifest(manifest);

      stopwatch.stop();
      _lastSyncTime = DateTime.now();
      _status = conflicts > 0 ? SyncStatus.conflict : SyncStatus.success;

      _lastResult = SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        deleted: deleted,
        duration: stopwatch.elapsed,
      );

      return _lastResult!;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      stopwatch.stop();

      _lastResult = SyncResult(
        success: false,
        errorMessage: e.toString(),
        duration: stopwatch.elapsed,
      );

      return _lastResult!;
    } finally {
      _isSyncing = false;
    }
  }

  /// Load all local data from database
  Future<_LocalData> _loadLocalData(Database db) async {
    // Load todos
    final todoMaps = await db.query(
      'todo_item',
      where: 'deleted_at IS NULL',
    );
    final todoItems = todoMaps.map((m) => TodoItem.fromJson(m)).toList();

    // Load tag associations
    final tagAssocMaps = await db.query('todo_tags');
    final tagIdsByTodo = <String, List<String>>{};
    for (final m in tagAssocMaps) {
      final todoId = m['todo_id'] as String;
      final tagId = m['tag_id'] as String;
      tagIdsByTodo.putIfAbsent(todoId, () => []).add(tagId);
    }

    final todos = <String, TodoSyncDto>{};
    for (final item in todoItems) {
      todos[item.id] =
          TodoSyncDto.fromTodoItem(item, tagIds: tagIdsByTodo[item.id] ?? []);
    }

    // Load categories
    final catMaps = await db.query('categories');
    final categories = <String, CategorySyncDto>{};
    for (final m in catMaps) {
      final cat = Category.fromJson(m);
      categories[cat.id] = CategorySyncDto.fromCategory(cat);
    }

    // Load tags
    final tagMaps = await db.query('tags');
    final tags = <String, TagSyncDto>{};
    for (final m in tagMaps) {
      final tag = Tag.fromJson(m);
      tags[tag.id] = TagSyncDto.fromTag(tag);
    }

    // Load reminders
    final reminderMaps = await db.query('reminders');
    final reminders = <String, ReminderSyncDto>{};
    for (final m in reminderMaps) {
      final dto = ReminderSyncDto.fromMap(m);
      reminders[dto.id] = dto;
    }

    return _LocalData(
      todos: todos,
      categories: categories,
      tags: tags,
      reminders: reminders,
    );
  }

  /// Load baseline hashes from sync_records table
  Future<Map<String, Map<String, String>>> _loadBaselineHashes(
      Database db) async {
    final rows = await db.query('sync_records');
    final result = <String, Map<String, String>>{};
    for (final row in rows) {
      final entityType = row['entity_type'] as String;
      final entityId = row['entity_id'] as String;
      final baselineHash = row['baseline_hash'] as String?;
      if (baselineHash != null) {
        result.putIfAbsent(entityType, () => {})[entityId] = baselineHash;
      }
    }
    return result;
  }

  /// Execute a single todo sync action
  Future<(int, int, int, int)> _executeTodoAction(
    Database db,
    SyncPlanItem item,
    Map<String, TodoSyncDto> local,
    Map<String, TodoSyncDto> remote,
  ) async {
    int up = 0, down = 0, conflict = 0, del = 0;

    switch (item.action) {
      case SyncAction.upload:
        // Local is newer → already included in local map, will be uploaded in merge
        up++;
        break;
      case SyncAction.download:
        // Remote is newer → apply to local DB
        final dto = remote[item.entityId];
        if (dto != null) {
          await _upsertLocalTodo(db, dto);
        }
        down++;
        break;
      case SyncAction.deleteLocal:
        await db
            .delete('todo_item', where: 'id = ?', whereArgs: [item.entityId]);
        await db.delete('todo_tags',
            where: 'todo_id = ?', whereArgs: [item.entityId]);
        del++;
        break;
      case SyncAction.deleteRemote:
        // Will be removed from remote during merge
        del++;
        break;
      case SyncAction.conflict:
        // Apply conflict strategy (already resolved by planner for non-manual)
        conflict++;
        break;
      case SyncAction.none:
        break;
    }

    return (up, down, conflict, del);
  }

  /// Execute a single category sync action
  Future<(int, int, int, int)> _executeCategoryAction(
    Database db,
    SyncPlanItem item,
    Map<String, CategorySyncDto> local,
    Map<String, CategorySyncDto> remote,
  ) async {
    int up = 0, down = 0, conflict = 0, del = 0;

    switch (item.action) {
      case SyncAction.upload:
        up++;
        break;
      case SyncAction.download:
        final dto = remote[item.entityId];
        if (dto != null) {
          await _upsertLocalCategory(db, dto);
        }
        down++;
        break;
      case SyncAction.deleteLocal:
        await db
            .delete('categories', where: 'id = ?', whereArgs: [item.entityId]);
        await db.update('todo_item', {'category_id': null},
            where: 'category_id = ?', whereArgs: [item.entityId]);
        del++;
        break;
      case SyncAction.deleteRemote:
        del++;
        break;
      case SyncAction.conflict:
        conflict++;
        break;
      case SyncAction.none:
        break;
    }

    return (up, down, conflict, del);
  }

  /// Execute a single tag sync action
  Future<(int, int, int, int)> _executeTagAction(
    Database db,
    SyncPlanItem item,
    Map<String, TagSyncDto> local,
    Map<String, TagSyncDto> remote,
  ) async {
    int up = 0, down = 0, conflict = 0, del = 0;

    switch (item.action) {
      case SyncAction.upload:
        up++;
        break;
      case SyncAction.download:
        final dto = remote[item.entityId];
        if (dto != null) {
          await _upsertLocalTag(db, dto);
        }
        down++;
        break;
      case SyncAction.deleteLocal:
        await db.delete('tags', where: 'id = ?', whereArgs: [item.entityId]);
        await db.delete('todo_tags',
            where: 'tag_id = ?', whereArgs: [item.entityId]);
        del++;
        break;
      case SyncAction.deleteRemote:
        del++;
        break;
      case SyncAction.conflict:
        conflict++;
        break;
      case SyncAction.none:
        break;
    }

    return (up, down, conflict, del);
  }

  /// Execute a single reminder sync action
  Future<(int, int, int, int)> _executeReminderAction(
    Database db,
    SyncPlanItem item,
    Map<String, ReminderSyncDto> local,
    Map<String, ReminderSyncDto> remote,
  ) async {
    int up = 0, down = 0, conflict = 0, del = 0;

    switch (item.action) {
      case SyncAction.upload:
        up++;
        break;
      case SyncAction.download:
        final dto = remote[item.entityId];
        if (dto != null) {
          await _upsertLocalReminder(db, dto);
        }
        down++;
        break;
      case SyncAction.deleteLocal:
        await db
            .delete('reminders', where: 'id = ?', whereArgs: [item.entityId]);
        del++;
        break;
      case SyncAction.deleteRemote:
        del++;
        break;
      case SyncAction.conflict:
        conflict++;
        break;
      case SyncAction.none:
        break;
    }

    return (up, down, conflict, del);
  }

  /// Merge local and remote maps after applying sync actions.
  /// The result represents the new state of the remote.
  Future<Map<String, T>> _mergeAfterSync<T>(
    Map<String, T> local,
    Map<String, T> remote,
    SyncPlan plan,
  ) async {
    final merged = <String, T>{...remote}; // Start with remote

    for (final item in plan.items) {
      switch (item.action) {
        case SyncAction.upload:
          // Local wins → overwrite remote with local
          final localItem = local[item.entityId];
          if (localItem != null) {
            merged[item.entityId] = localItem;
          }
          break;
        case SyncAction.download:
          // Remote wins → local was updated, merged already has remote version
          // Also update merged to include the remote version (already there)
          break;
        case SyncAction.deleteLocal:
          // Remote deleted → remove from merged
          merged.remove(item.entityId);
          break;
        case SyncAction.deleteRemote:
          // Local deleted → remove from merged
          merged.remove(item.entityId);
          break;
        case SyncAction.conflict:
          // For conflict with localWins or latestModified where local wins
          if (item.conflictStrategy == ConflictStrategy.localWins) {
            final localItem = local[item.entityId];
            if (localItem != null) {
              merged[item.entityId] = localItem;
            }
          }
          // For remoteWins or latestModified where remote wins → keep remote version (already there)
          break;
        case SyncAction.none:
          // Ensure it's in merged
          if (!merged.containsKey(item.entityId) &&
              local.containsKey(item.entityId)) {
            final localItem = local[item.entityId];
            if (localItem != null) {
              merged[item.entityId] = localItem;
            }
          }
          break;
      }
    }

    // Also add any local items not in the plan (new local items)
    for (final entry in local.entries) {
      if (!merged.containsKey(entry.key)) {
        final isInPlan = plan.items.any((i) => i.entityId == entry.key);
        if (!isInPlan) {
          // New local item not covered by plan → upload it
          merged[entry.key] = entry.value;
        }
      }
    }

    return merged;
  }

  /// Update baseline hashes in sync_records
  Future<void> _updateBaselineHashes(
    Database db, {
    required Map<String, TodoSyncDto> mergedTodos,
    required Map<String, CategorySyncDto> mergedCategories,
    required Map<String, TagSyncDto> mergedTags,
    required Map<String, ReminderSyncDto> mergedReminders,
    required int timestamp,
  }) async {
    final batch = db.batch();

    // Clear existing records
    batch.delete('sync_records');

    // Insert new baseline records for todos
    for (final entry in mergedTodos.entries) {
      final hash = _serializer.computeHash(jsonEncode(entry.value.toJson()));
      batch.insert('sync_records', {
        'entity_id': entry.key,
        'entity_type': 'todo',
        'baseline_hash': hash,
        'remote_hash': hash,
        'last_synced_at': timestamp,
      });
    }

    // Insert for categories
    for (final entry in mergedCategories.entries) {
      final hash = _serializer.computeHash(jsonEncode(entry.value.toJson()));
      batch.insert('sync_records', {
        'entity_id': entry.key,
        'entity_type': 'category',
        'baseline_hash': hash,
        'remote_hash': hash,
        'last_synced_at': timestamp,
      });
    }

    // Insert for tags
    for (final entry in mergedTags.entries) {
      final hash = _serializer.computeHash(jsonEncode(entry.value.toJson()));
      batch.insert('sync_records', {
        'entity_id': entry.key,
        'entity_type': 'tag',
        'baseline_hash': hash,
        'remote_hash': hash,
        'last_synced_at': timestamp,
      });
    }

    // Insert for reminders
    for (final entry in mergedReminders.entries) {
      final hash = _serializer.computeHash(jsonEncode(entry.value.toJson()));
      batch.insert('sync_records', {
        'entity_id': entry.key,
        'entity_type': 'reminder',
        'baseline_hash': hash,
        'remote_hash': hash,
        'last_synced_at': timestamp,
      });
    }

    await batch.commit(noResult: true);
  }

  bool _shouldBootstrapFromRemote({
    required _LocalData localData,
    required Map<String, TodoSyncDto> remoteTodos,
    required Map<String, CategorySyncDto> remoteCategories,
    required Map<String, TagSyncDto> remoteTags,
    required Map<String, ReminderSyncDto> remoteReminders,
  }) {
    final localIsEmpty = localData.todos.isEmpty &&
        localData.categories.isEmpty &&
        localData.tags.isEmpty &&
        localData.reminders.isEmpty;

    final remoteHasData = remoteTodos.isNotEmpty ||
        remoteCategories.isNotEmpty ||
        remoteTags.isNotEmpty ||
        remoteReminders.isNotEmpty;

    return localIsEmpty && remoteHasData;
  }

  Future<void> _applyRemoteSnapshot(
    Database db, {
    required Map<String, TodoSyncDto> remoteTodos,
    required Map<String, CategorySyncDto> remoteCategories,
    required Map<String, TagSyncDto> remoteTags,
    required Map<String, ReminderSyncDto> remoteReminders,
  }) async {
    for (final dto in remoteTodos.values) {
      await _upsertLocalTodo(db, dto);
    }

    for (final dto in remoteCategories.values) {
      await _upsertLocalCategory(db, dto);
    }

    for (final dto in remoteTags.values) {
      await _upsertLocalTag(db, dto);
    }

    for (final dto in remoteReminders.values) {
      await _upsertLocalReminder(db, dto);
    }
  }

  // ---- Local DB upsert helpers ----

  Future<void> _upsertLocalTodo(Database db, TodoSyncDto dto) async {
    final item = dto.toTodoItem();
    await db.insert(
      'todo_item',
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Also update tag associations
    await db.delete('todo_tags', where: 'todo_id = ?', whereArgs: [dto.id]);
    for (final tagId in dto.tagIds) {
      await db.insert(
        'todo_tags',
        {'todo_id': dto.id, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _upsertLocalCategory(Database db, CategorySyncDto dto) async {
    await db.insert(
      'categories',
      dto.toCategory().toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertLocalTag(Database db, TagSyncDto dto) async {
    await db.insert(
      'tags',
      dto.toTag().toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertLocalReminder(Database db, ReminderSyncDto dto) async {
    await db.insert(
      'reminders',
      {
        'id': dto.id,
        'todo_id': dto.todoId,
        'notification_id': dto.notificationId,
        'remind_at': dto.remindAt,
        'fired': dto.fired,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Container for all local data loaded from the database
class _LocalData {
  final Map<String, TodoSyncDto> todos;
  final Map<String, CategorySyncDto> categories;
  final Map<String, TagSyncDto> tags;
  final Map<String, ReminderSyncDto> reminders;

  const _LocalData({
    required this.todos,
    required this.categories,
    required this.tags,
    required this.reminders,
  });
}
