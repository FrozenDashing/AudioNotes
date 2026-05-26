import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo_item.dart';

/// Database helper for managing todo items
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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
      version: 2, // Increment version for new fields
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
        created_at $intType,
        updated_at $nullableIntType,
        audio_path $nullableTextType,
        task_state INTEGER DEFAULT 2,
        status INTEGER DEFAULT 0,
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

    final updated = todo.copyWith(status: status);
    await updateTodo(updated);
    return updated;
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
