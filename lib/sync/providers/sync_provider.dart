import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../client/webdav_client_wrapper.dart';
import '../coordinator/sync_coordinator.dart';
import '../planner/sync_planner.dart';
import 'webdav_settings_service.dart';

/// Provider for WebDAV settings service
final webdavSettingsServiceProvider = Provider<WebDavSettingsService>((ref) {
  return WebDavSettingsService();
});

/// Provider for WebDAV client wrapper
final webdavClientProvider = Provider<WebDavClientWrapper>((ref) {
  return WebDavClientWrapper();
});

/// Provider for SyncCoordinator
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final clientWrapper = ref.read(webdavClientProvider);
  return SyncCoordinator(clientWrapper: clientWrapper);
});

/// Notifier for managing sync state
class SyncNotifier extends Notifier<SyncState> {
  late final SyncCoordinator _coordinator;
  late final WebDavSettingsService _settingsService;
  Timer? _periodicTimer;

  @override
  SyncState build() {
    _coordinator = ref.read(syncCoordinatorProvider);
    _settingsService = ref.read(webdavSettingsServiceProvider);
    // Load saved config on init
    unawaited(_loadConfig());
    ref.onDispose(() {
      _periodicTimer?.cancel();
    });
    return SyncState.initial();
  }

  /// Load saved WebDAV config and apply to coordinator
  Future<void> _loadConfig() async {
    try {
      final config = await _settingsService.loadConfig();
      if (config.isConfigured) {
        _coordinator.configure(
          baseUrl: config.baseUrl,
          username: config.username,
          password: config.password,
          remoteDir: config.remoteDir,
        );
        _coordinator.setConflictStrategy(config.conflictStrategy);
        state = state.copyWith(
          isConfigured: true,
          autoSync: config.autoSync,
          syncIntervalMinutes: config.syncIntervalMinutes,
          conflictStrategy: config.conflictStrategy,
          syncOnStartup: config.syncOnStartup,
        );

        if (config.syncOnStartup) {
          unawaited(syncNow());
        }

        if (config.autoSync) {
          _startPeriodicSync(config.syncIntervalMinutes);
        }
      }
    } catch (e) {
      foundation.debugPrint('Failed to load WebDAV config on init: $e');
    }
  }

  /// Configure WebDAV connection
  Future<bool> configureAndSave(WebDavConfig config) async {
    try {
      await _settingsService.saveConfig(config);
      _coordinator.configure(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
        remoteDir: config.remoteDir,
      );
      _coordinator.setConflictStrategy(config.conflictStrategy);

      state = state.copyWith(
        isConfigured: true,
        autoSync: config.autoSync,
        syncIntervalMinutes: config.syncIntervalMinutes,
        conflictStrategy: config.conflictStrategy,
        syncOnStartup: config.syncOnStartup,
      );

      if (config.autoSync) {
        _startPeriodicSync(config.syncIntervalMinutes);
      } else {
        _periodicTimer?.cancel();
      }

      return true;
    } catch (e) {
      foundation.debugPrint('Failed to configure WebDAV: $e');
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Test the WebDAV connection
  Future<bool> testConnection() async {
    try {
      return await _coordinator.testConnection();
    } catch (e) {
      foundation.debugPrint('WebDAV test connection failed: $e');
      return false;
    }
  }

  /// Execute a manual sync
  Future<SyncResult> syncNow() async {
    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    final result = await _coordinator.syncNow();

    if (result.success) {
      // 主动调用 loadTodos() 确保数据立即从数据库重新加载
      await ref.read(todoListProvider.notifier).loadTodos();
      // 刷新其他相关 providers
      ref.invalidate(categoryListProvider);
      ref.invalidate(tagListProvider);
      ref.invalidate(tagsForTodoProvider);
      ref.read(todoTagsCacheNotifierProvider.notifier).invalidate();
    }

    state = state.copyWith(
      status: _coordinator.status,
      lastSyncTime: _coordinator.lastSyncTime,
      lastResult: result,
      errorMessage: result.errorMessage,
    );

    return result;
  }

  /// Disconnect and clear WebDAV config
  Future<void> disconnect() async {
    _periodicTimer?.cancel();
    await _settingsService.clearConfig();
    _coordinator.reset();

    state = SyncState.initial();
  }

  /// Set conflict strategy
  Future<void> setConflictStrategy(ConflictStrategy strategy) async {
    _coordinator.setConflictStrategy(strategy);
    state = state.copyWith(conflictStrategy: strategy);

    final config = await _settingsService.loadConfig();
    await _settingsService
        .saveConfig(config.copyWith(conflictStrategy: strategy));
  }

  /// Toggle auto sync
  Future<void> setAutoSync(bool enabled) async {
    state = state.copyWith(autoSync: enabled);

    final config = await _settingsService.loadConfig();
    await _settingsService.saveConfig(config.copyWith(autoSync: enabled));

    if (enabled) {
      _startPeriodicSync(state.syncIntervalMinutes);
    } else {
      _periodicTimer?.cancel();
    }
  }

  /// Set sync interval
  Future<void> setSyncInterval(int minutes) async {
    state = state.copyWith(syncIntervalMinutes: minutes);

    final config = await _settingsService.loadConfig();
    await _settingsService
        .saveConfig(config.copyWith(syncIntervalMinutes: minutes));

    if (state.autoSync) {
      _startPeriodicSync(minutes);
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync(int minutes) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      syncNow();
    });
  }
}

/// State for the sync feature
class SyncState {
  final bool isConfigured;
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final SyncResult? lastResult;
  final String? errorMessage;
  final bool autoSync;
  final int syncIntervalMinutes;
  final ConflictStrategy conflictStrategy;
  final bool syncOnStartup;

  const SyncState({
    required this.isConfigured,
    required this.status,
    this.lastSyncTime,
    this.lastResult,
    this.errorMessage,
    required this.autoSync,
    required this.syncIntervalMinutes,
    required this.conflictStrategy,
    required this.syncOnStartup,
  });

  factory SyncState.initial() => const SyncState(
        isConfigured: false,
        status: SyncStatus.idle,
        autoSync: false,
        syncIntervalMinutes: 30,
        conflictStrategy: ConflictStrategy.latestModified,
        syncOnStartup: false,
      );

  SyncState copyWith({
    bool? isConfigured,
    SyncStatus? status,
    DateTime? lastSyncTime,
    SyncResult? lastResult,
    String? errorMessage,
    bool? autoSync,
    int? syncIntervalMinutes,
    ConflictStrategy? conflictStrategy,
    bool? syncOnStartup,
  }) {
    return SyncState(
      isConfigured: isConfigured ?? this.isConfigured,
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage ?? this.errorMessage,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
    );
  }
}

/// Provider for sync notifier
final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Provider for sync status (convenience)
final syncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncProvider).status;
});

/// Provider for last sync time (convenience)
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncProvider).lastSyncTime;
});
