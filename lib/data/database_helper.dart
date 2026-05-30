import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo_item.dart';
import '../models/category.dart';
import '../models/tag.dart';
import '../models/todo_priority.dart';
import '../models/todo_query_options.dart';
import '../models/todo_sort.dart';
import 'todo_query_builder.dart';

/// Database helper for managing todo items
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 8;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('audionotes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        // Enable foreign keys support
        await db.execute('PRAGMA foreign_keys=ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    const nullableTextType = 'TEXT';
    const nullableIntType = 'INTEGER';

    await db.execute('''
      CREATE TABLE todo_item (
        id $idType,
        text $textType,
        raw_text $nullableTextType,
        created_at $intType,
        updated_at $nullableIntType,
        audio_path $nullableTextType,
        task_state INTEGER NOT NULL DEFAULT 2,
        status INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 1,
        due_at $nullableIntType,
        remind_at $nullableIntType,
        repeat_type INTEGER NOT NULL DEFAULT 0,
        repeat_rule $nullableTextType,
        category_id $nullableTextType,
        pinned INTEGER NOT NULL DEFAULT 0,
        completed_at $nullableIntType,
        deleted_at $nullableIntType,
        error_message $nullableTextType,
        model_version $nullableTextType,
        order_index $nullableIntType,
        meta $nullableTextType
      )
    ''');

    await db.execute('CREATE INDEX idx_created_at ON todo_item(created_at)');
    await db.execute('CREATE INDEX idx_order_index ON todo_item(order_index)');
    await db.execute('CREATE INDEX idx_task_state ON todo_item(task_state)');
    await db.execute('CREATE INDEX idx_priority ON todo_item(priority)');
    await db.execute('CREATE INDEX idx_due_at ON todo_item(due_at)');
    await db.execute('CREATE INDEX idx_remind_at ON todo_item(remind_at)');
    await db.execute('CREATE INDEX idx_category_id ON todo_item(category_id)');
    await db.execute('CREATE INDEX idx_deleted_at ON todo_item(deleted_at)');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER,
        sort_order INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE todo_tags (
        todo_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (todo_id, tag_id),
        FOREIGN KEY (todo_id) REFERENCES todo_item(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        todo_id TEXT NOT NULL,
        notification_id INTEGER NOT NULL,
        remind_at INTEGER NOT NULL,
        fired INTEGER DEFAULT 0,
        UNIQUE(todo_id),
        UNIQUE(notification_id),
        FOREIGN KEY (todo_id) REFERENCES todo_item(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE UNIQUE INDEX idx_reminders_todo_id ON reminders(todo_id)');
    await db.execute(
        'CREATE UNIQUE INDEX idx_reminders_notification_id ON reminders(notification_id)');
    await db.execute(
        'CREATE INDEX idx_reminders_remind_at ON reminders(remind_at)');

    // Sync records: track baseline/remote hashes and last sync time per entity
    await db.execute('''
      CREATE TABLE sync_records (
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        baseline_hash TEXT,
        remote_hash TEXT,
        last_synced_at INTEGER,
        PRIMARY KEY (entity_id, entity_type)
      )
    ''');

    // Sync jobs: track pending upload/download operations and retries
    await db.execute('''
      CREATE TABLE sync_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        dirty_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_sync_jobs_entity ON sync_jobs(entity_id, entity_type)');
    await db.execute(
        'CREATE INDEX idx_sync_jobs_operation ON sync_jobs(operation)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for task lifecycle management
      await db.execute(
          'ALTER TABLE todo_item ADD COLUMN task_state INTEGER DEFAULT 2');
      await db.execute('ALTER TABLE todo_item ADD COLUMN error_message TEXT');
      await db.execute('ALTER TABLE todo_item ADD COLUMN model_version TEXT');

      // Create index for task_state
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_task_state ON todo_item(task_state)');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE todo_item ADD COLUMN raw_text TEXT');
      await db.execute('ALTER TABLE todo_item ADD COLUMN due_at INTEGER');
      await db.execute('ALTER TABLE todo_item ADD COLUMN remind_at INTEGER');
      await db.execute(
          'ALTER TABLE todo_item ADD COLUMN repeat_type INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE todo_item ADD COLUMN repeat_rule TEXT');
      await db.execute('ALTER TABLE todo_item ADD COLUMN category_id TEXT');
      await db.execute(
          'ALTER TABLE todo_item ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE todo_item ADD COLUMN completed_at INTEGER');
      await db.execute('ALTER TABLE todo_item ADD COLUMN deleted_at INTEGER');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_due_at ON todo_item(due_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_remind_at ON todo_item(remind_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_category_id ON todo_item(category_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_deleted_at ON todo_item(deleted_at)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color INTEGER,
          sort_order INTEGER DEFAULT 0,
          is_hidden INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS todo_tags (
          todo_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (todo_id, tag_id),
          FOREIGN KEY (todo_id) REFERENCES todo_item(id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS reminders (
          id TEXT PRIMARY KEY,
          todo_id TEXT NOT NULL,
          remind_at INTEGER NOT NULL,
          fired INTEGER DEFAULT 0,
          FOREIGN KEY (todo_id) REFERENCES todo_item(id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
        'UPDATE todo_item SET raw_text = text WHERE raw_text IS NULL',
      );
    }

    if (oldVersion < 4) {
      await db
          .execute('ALTER TABLE reminders ADD COLUMN notification_id INTEGER');
      await db.execute(
          'UPDATE reminders SET notification_id = rowid WHERE notification_id IS NULL');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_reminders_todo_id ON reminders(todo_id)');
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_reminders_notification_id ON reminders(notification_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON reminders(remind_at)');
    }

    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE todo_item ADD COLUMN priority INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_priority ON todo_item(priority)');
    }

    if (oldVersion < 6) {
      // Sync records: track baseline/remote hashes and last sync time per entity
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_records (
          entity_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          baseline_hash TEXT,
          remote_hash TEXT,
          last_synced_at INTEGER,
          PRIMARY KEY (entity_id, entity_type)
        )
      ''');

      // Sync jobs: track pending upload/download operations and retries
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_jobs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          operation TEXT NOT NULL,
          dirty_at INTEGER NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_jobs_entity ON sync_jobs(entity_id, entity_type)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_jobs_operation ON sync_jobs(operation)');
    }

    if (oldVersion < 8) {
      await _rebuildTodoItemTableWithoutConfidence(db);
    }
  }

  Future<void> _rebuildTodoItemTableWithoutConfidence(Database db) async {
    await db.execute('PRAGMA foreign_keys=OFF');

    try {
      await db.execute('ALTER TABLE todo_item RENAME TO todo_item_old');

      await db.execute('''
        CREATE TABLE todo_item (
          id TEXT PRIMARY KEY,
          text TEXT NOT NULL,
          raw_text TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          audio_path TEXT,
          task_state INTEGER NOT NULL DEFAULT 2,
          status INTEGER NOT NULL DEFAULT 0,
          priority INTEGER NOT NULL DEFAULT 1,
          due_at INTEGER,
          remind_at INTEGER,
          repeat_type INTEGER NOT NULL DEFAULT 0,
          repeat_rule TEXT,
          category_id TEXT,
          pinned INTEGER NOT NULL DEFAULT 0,
          completed_at INTEGER,
          deleted_at INTEGER,
          error_message TEXT,
          model_version TEXT,
          order_index INTEGER,
          meta TEXT
        )
      ''');

      await db.execute('''
        INSERT INTO todo_item (
          id,
          text,
          raw_text,
          created_at,
          updated_at,
          audio_path,
          task_state,
          status,
          priority,
          due_at,
          remind_at,
          repeat_type,
          repeat_rule,
          category_id,
          pinned,
          completed_at,
          deleted_at,
          error_message,
          model_version,
          order_index,
          meta
        )
        SELECT
          id,
          text,
          raw_text,
          created_at,
          updated_at,
          audio_path,
          task_state,
          status,
          priority,
          due_at,
          remind_at,
          repeat_type,
          repeat_rule,
          category_id,
          pinned,
          completed_at,
          deleted_at,
          error_message,
          model_version,
          order_index,
          meta
        FROM todo_item_old
      ''');

      await db.execute('DROP TABLE todo_item_old');

      await db.execute('CREATE INDEX idx_created_at ON todo_item(created_at)');
      await db
          .execute('CREATE INDEX idx_order_index ON todo_item(order_index)');
      await db.execute('CREATE INDEX idx_task_state ON todo_item(task_state)');
      await db.execute('CREATE INDEX idx_priority ON todo_item(priority)');
      await db.execute('CREATE INDEX idx_due_at ON todo_item(due_at)');
      await db.execute('CREATE INDEX idx_remind_at ON todo_item(remind_at)');
      await db
          .execute('CREATE INDEX idx_category_id ON todo_item(category_id)');
      await db.execute('CREATE INDEX idx_deleted_at ON todo_item(deleted_at)');
    } finally {
      await db.execute('PRAGMA foreign_keys=ON');
    }
  }

  /// Insert a new todo item
  Future<TodoItem> insertTodo(TodoItem todo) async {
    final db = await database;

    await db.insert(
      'todo_item',
      todo.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return todo;
  }

  /// Get the next order index for a newly inserted todo item
  Future<int> getNextOrderIndex() async {
    final db = await database;

    final maps = await db
        .rawQuery('SELECT MAX(order_index) AS max_order_index FROM todo_item');
    final maxOrderIndex = maps.first['max_order_index'] as int?;
    return (maxOrderIndex ?? -1) + 1;
  }

  /// Get all todo items sorted by created_at or order_index, optionally including deleted items
  Future<List<TodoItem>> getAllTodos({
    bool sortByOrder = false,
    bool includeDeleted = false,
  }) async {
    final options = TodoQueryOptions(
      sortField: sortByOrder ? TodoSortField.manual : TodoSortField.createdAt,
      direction: sortByOrder ? SortDirection.asc : SortDirection.desc,
    );

    return getTodos(options, includeDeleted: includeDeleted);
  }

  /// Get todo items based on query options
  Future<List<TodoItem>> getTodos(
    TodoQueryOptions options, {
    bool sortInDatabase = true,
    bool includeDeleted = false,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (!includeDeleted) {
      whereClauses.add('deleted_at IS NULL');
    }

    if (options.onlyPending) {
      whereClauses.add('status = ?');
      whereArgs.add(TodoStatus.pending.value);
    }

    if (options.categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(options.categoryId);
    }

    final orderBy = sortInDatabase
        ? TodoQueryBuilder.buildOrderBy(options.sortField, options.direction)
        : null;
    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final maps = await db.query(
      'todo_item',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: orderBy,
    );

    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Get a single todo item by ID
  Future<TodoItem?> getTodoById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final db = await database;

    final whereClauses = <String>['id = ?'];
    final whereArgs = <Object?>[id];

    if (!includeDeleted) {
      whereClauses.add('deleted_at IS NULL');
    }

    final maps = await db.query(
      'todo_item',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
    );

    if (maps.isNotEmpty) {
      return TodoItem.fromJson(maps.first);
    }
    return null;
  }

  /// Update a todo item
  Future<int> updateTodo(TodoItem todo) async {
    final db = await database;

    return await db.update(
      'todo_item',
      todo.copyWith(updatedAt: DateTime.now()).toJson(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  /// Soft delete a todo item by moving it to the trash
  Future<int> deleteTodo(String id) async {
    final db = await database;

    return await db.update(
      'todo_item',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  /// Restore a todo item from the trash
  Future<int> restoreTodo(String id) async {
    final db = await database;

    return await db.update(
      'todo_item',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at IS NOT NULL',
      whereArgs: [id],
    );
  }

  /// Permanently delete a todo item and all of its persisted side effects
  Future<void> purgeTodoPermanently(String id) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'sync_jobs',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [id, 'todo'],
      );
      await txn.delete(
        'sync_records',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [id, 'todo'],
      );
      await txn.delete(
        'todo_item',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Update order indices for multiple items
  Future<void> updateOrderIndices(Map<String, int> orderMap) async {
    final db = await database;
    final batch = db.batch();

    orderMap.forEach((id, orderIndex) {
      batch.update(
        'todo_item',
        {'order_index': orderIndex},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    await batch.commit(noResult: true);
  }

  /// Toggle completion status
  Future<TodoItem?> toggleStatus(String id) async {
    final todo = await getTodoById(id);
    if (todo == null) return null;

    final newStatus = todo.status == TodoStatus.pending
        ? TodoStatus.completed
        : TodoStatus.pending;

    return setStatus(id, newStatus);
  }

  /// Set completion status explicitly
  Future<TodoItem?> setStatus(String id, TodoStatus status) async {
    final todo = await getTodoById(id);
    if (todo == null) return null;

    final updated = todo.copyWith(
      status: status,
      completedAt: status == TodoStatus.completed ? DateTime.now() : null,
    );
    await updateTodo(updated);
    return updated;
  }

  /// Set or clear the due time of a todo item
  Future<int> updateDueAt(String id, DateTime? dueAt) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'due_at': dueAt?.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Set or clear the reminder time of a todo item
  Future<int> updateRemindAt(String id, DateTime? remindAt) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'remind_at': remindAt?.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update the repeat rule of a todo item
  Future<int> updateRepeatRule(
    String id,
    TodoRepeatType repeatType, {
    String? repeatRule,
  }) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'repeat_type': repeatType.value,
        'repeat_rule': repeatRule,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update the category of a todo item
  Future<int> updateCategory(String id, String? categoryId) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'category_id': categoryId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update the pinned state of a todo item
  Future<int> updatePinned(String id, bool pinned) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update the priority of a todo item
  Future<int> updatePriority(String id, TodoPriority priority) async {
    final db = await database;
    return db.update(
      'todo_item',
      {
        'priority': priority.value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Insert or replace a reminder row for a todo item
  Future<void> upsertReminder({
    required String reminderId,
    required String todoId,
    required int notificationId,
    required DateTime remindAt,
    int fired = 0,
  }) async {
    final db = await database;
    await db.insert(
      'reminders',
      {
        'id': reminderId,
        'todo_id': todoId,
        'notification_id': notificationId,
        'remind_at': remindAt.millisecondsSinceEpoch,
        'fired': fired,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch reminder metadata for a todo item
  Future<Map<String, dynamic>?> getReminderByTodoId(String todoId) async {
    final db = await database;
    final rows = await db.query(
      'reminders',
      where: 'todo_id = ?',
      whereArgs: [todoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch reminders that are due before a point in time
  Future<List<Map<String, dynamic>>> getRemindersDueBefore(
    DateTime before,
  ) async {
    final db = await database;
    return db.query(
      'reminders',
      where: 'remind_at <= ? AND fired = 0',
      whereArgs: [before.millisecondsSinceEpoch],
      orderBy: 'remind_at ASC',
    );
  }

  /// Get all reminder rows
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    final db = await database;
    return db.query(
      'reminders',
      orderBy: 'remind_at ASC',
    );
  }

  /// Mark a reminder as fired
  Future<int> markReminderFired(int notificationId) async {
    final db = await database;
    return db.update(
      'reminders',
      {'fired': 1},
      where: 'notification_id = ?',
      whereArgs: [notificationId],
    );
  }

  /// Delete a reminder by todo ID
  Future<int> deleteReminderByTodoId(String todoId) async {
    final db = await database;
    return db.delete(
      'reminders',
      where: 'todo_id = ?',
      whereArgs: [todoId],
    );
  }

  /// Get the next reminder notification ID
  Future<int> getNextReminderNotificationId() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(notification_id) AS max_notification_id FROM reminders',
    );
    final maxNotificationId = rows.first['max_notification_id'] as int?;
    return (maxNotificationId ?? 0) + 1;
  }

  /// Get todos by task state
  Future<List<TodoItem>> getTodosByTaskState(
    TodoTaskState state, {
    bool includeDeleted = false,
  }) async {
    final db = await database;

    final whereClauses = <String>['task_state = ?'];
    final whereArgs = <Object?>[state.value];

    if (!includeDeleted) {
      whereClauses.add('deleted_at IS NULL');
    }

    final maps = await db.query(
      'todo_item',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Get todos by category
  Future<List<TodoItem>> getTodosByCategory(
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    final db = await database;
    final whereClauses = <String>['category_id = ?'];
    final whereArgs = <Object?>[categoryId];

    if (!includeDeleted) {
      whereClauses.add('deleted_at IS NULL');
    }

    final maps = await db.query(
      'todo_item',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Get todos by tag
  Future<List<TodoItem>> getTodosByTag(
    String tagId, {
    bool includeDeleted = false,
  }) async {
    final db = await database;
    final deletedFilter = includeDeleted ? '' : 'AND t.deleted_at IS NULL';
    final maps = await db.rawQuery('''
      SELECT t.*
      FROM todo_item t
      INNER JOIN todo_tags tt ON tt.todo_id = t.id
      WHERE tt.tag_id = ? $deletedFilter
      ORDER BY t.created_at DESC
    ''', [tagId]);
    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Get deleted todos for the trash view
  Future<List<TodoItem>> getDeletedTodos() async {
    final db = await database;
    final maps = await db.query(
      'todo_item',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, updated_at DESC, created_at DESC',
    );
    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Purge todo records that have stayed in trash longer than [cutoff].
  Future<void> purgeDeletedTodosBefore(DateTime cutoff) async {
    final deletedTodos = await getDeletedTodos();
    for (final todo in deletedTodos) {
      final deletedAt = todo.deletedAt;
      if (deletedAt != null && deletedAt.isBefore(cutoff)) {
        await purgeTodoPermanently(todo.id);
      }
    }
  }

  /// Permanently delete every todo currently in trash.
  Future<void> purgeAllDeletedTodos() async {
    final deletedTodos = await getDeletedTodos();
    for (final todo in deletedTodos) {
      await purgeTodoPermanently(todo.id);
    }
  }

  /// Insert a category
  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a category
  Future<int> updateCategoryData(Category category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toJson(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Delete a category and clear references
  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'todo_item',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Get categories
  Future<List<Category>> getCategories({bool includeHidden = false}) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: includeHidden ? null : 'is_hidden = 0',
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((map) => Category.fromJson(map)).toList();
  }

  /// Insert a tag
  Future<void> insertTag(Tag tag) async {
    final db = await database;
    await db.insert(
      'tags',
      tag.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a tag
  Future<int> updateTagData(Tag tag) async {
    final db = await database;
    return db.update(
      'tags',
      tag.toJson(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  /// Delete a tag
  Future<int> deleteTag(String id) async {
    final db = await database;
    return db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get tags
  Future<List<Tag>> getTags() async {
    final db = await database;
    final maps = await db.query(
      'tags',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Tag.fromJson(map)).toList();
  }

  /// Get tags for a todo
  Future<List<Tag>> getTagsForTodo(String todoId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT tg.*
      FROM tags tg
      INNER JOIN todo_tags tt ON tt.tag_id = tg.id
      WHERE tt.todo_id = ?
      ORDER BY tg.name ASC
    ''', [todoId]);
    return maps.map((map) => Tag.fromJson(map)).toList();
  }

  /// Get tags for multiple todos (batch)
  Future<Map<String, List<Tag>>> getTagsForTodos(List<String> todoIds) async {
    if (todoIds.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(todoIds.length, '?').join(',');
    final maps = await db.rawQuery('''
      SELECT tt.todo_id as todo_id, tg.*
      FROM tags tg
      INNER JOIN todo_tags tt ON tt.tag_id = tg.id
      WHERE tt.todo_id IN ($placeholders)
      ORDER BY tg.name ASC
    ''', todoIds);
    final result = <String, List<Tag>>{};
    for (final id in todoIds) {
      result[id] = [];
    }
    for (final map in maps) {
      final todoId = map['todo_id'] as String;
      final tag = Tag.fromJson(map);
      result[todoId]!.add(tag);
    }
    return result;
  }

  /// Replace tags for a todo
  Future<void> setTagsForTodo(String todoId, List<String> tagIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'todo_tags',
        where: 'todo_id = ?',
        whereArgs: [todoId],
      );

      for (final tagId in tagIds) {
        await txn.insert(
          'todo_tags',
          {'todo_id': todoId, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
