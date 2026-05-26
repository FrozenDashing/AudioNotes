import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo_item.dart';

/// Database helper for managing todo items
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 4;

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
    const realType = 'REAL';
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
        due_at $nullableIntType,
        remind_at $nullableIntType,
        repeat_type INTEGER NOT NULL DEFAULT 0,
        repeat_rule $nullableTextType,
        category_id $nullableTextType,
        pinned INTEGER NOT NULL DEFAULT 0,
        completed_at $nullableIntType,
        deleted_at $nullableIntType,
        duration_ms $nullableIntType,
        error_message $nullableTextType,
        model_version $nullableTextType,
        order_index $nullableIntType,
        confidence $realType,
        meta $nullableTextType
      )
    ''');

    await db.execute('CREATE INDEX idx_created_at ON todo_item(created_at)');
    await db.execute('CREATE INDEX idx_order_index ON todo_item(order_index)');
    await db.execute('CREATE INDEX idx_task_state ON todo_item(task_state)');
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
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for task lifecycle management
      await db.execute(
          'ALTER TABLE todo_item ADD COLUMN task_state INTEGER DEFAULT 2');
      await db.execute('ALTER TABLE todo_item ADD COLUMN duration_ms INTEGER');
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

  /// Get all todo items sorted by created_at or order_index
  Future<List<TodoItem>> getAllTodos({bool sortByOrder = false}) async {
    final db = await database;

    final orderBy = sortByOrder
        ? 'CASE WHEN order_index IS NULL THEN 1 ELSE 0 END, order_index ASC, created_at ASC'
        : 'created_at DESC';

    final maps = await db.query(
      'todo_item',
      orderBy: orderBy,
    );

    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Get a single todo item by ID
  Future<TodoItem?> getTodoById(String id) async {
    final db = await database;

    final maps = await db.query(
      'todo_item',
      where: 'id = ?',
      whereArgs: [id],
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

  /// Delete a todo item
  Future<int> deleteTodo(String id) async {
    final db = await database;

    return await db.delete(
      'todo_item',
      where: 'id = ?',
      whereArgs: [id],
    );
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
  Future<List<TodoItem>> getTodosByTaskState(TodoTaskState state) async {
    final db = await database;

    final maps = await db.query(
      'todo_item',
      where: 'task_state = ?',
      whereArgs: [state.value],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => TodoItem.fromJson(map)).toList();
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
