import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../client/webdav_client_wrapper.dart';
import '../coordinator/sync_coordinator.dart';
import '../providers/webdav_settings_service.dart';

const String _backgroundSyncTaskName = 'webdav_background_sync';
const String _backgroundSyncUniqueName = 'webdav_background_sync_periodic';
const String _backgroundSyncStateKey = 'webdav_background_sync_state';
const String _backgroundSyncMessageKey = 'webdav_background_sync_message';
const String _backgroundSyncUpdatedAtKey = 'webdav_background_sync_updated_at';

enum BackgroundSyncPhase { idle, syncing, success, error }

class BackgroundSyncState {
  final BackgroundSyncPhase phase;
  final DateTime? updatedAt;
  final String? message;

  const BackgroundSyncState({
    required this.phase,
    this.updatedAt,
    this.message,
  });

  const BackgroundSyncState.idle() : this(phase: BackgroundSyncPhase.idle);
}

class BackgroundSyncStatusStore {
  Future<BackgroundSyncState> readState() async {
    final prefs = await SharedPreferences.getInstance();
    final phaseName = prefs.getString(_backgroundSyncStateKey) ?? 'idle';
    return BackgroundSyncState(
      phase: _parsePhase(phaseName),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt(_backgroundSyncUpdatedAtKey) ?? 0,
        isUtc: true,
      ).toLocal(),
      message: prefs.getString(_backgroundSyncMessageKey),
    );
  }

  Future<void> markSyncing({String? message}) async {
    await _write(BackgroundSyncPhase.syncing, message: message);
  }

  Future<void> markFinished({
    required bool success,
    String? message,
  }) async {
    await _write(
        success ? BackgroundSyncPhase.success : BackgroundSyncPhase.error,
        message: message);
  }

  Future<void> markIdle() async {
    await _write(BackgroundSyncPhase.idle);
  }

  Future<void> _write(
    BackgroundSyncPhase phase, {
    String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundSyncStateKey, phase.name);
    await prefs.setString(_backgroundSyncMessageKey, message ?? '');
    await prefs.setInt(
      _backgroundSyncUpdatedAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  BackgroundSyncPhase _parsePhase(String value) {
    return BackgroundSyncPhase.values.firstWhere(
      (phase) => phase.name == value,
      orElse: () => BackgroundSyncPhase.idle,
    );
  }
}

final backgroundSyncStatusStoreProvider =
    Provider<BackgroundSyncStatusStore>((ref) {
  return BackgroundSyncStatusStore();
});

final backgroundSyncService = BackgroundSyncService(
  statusStore: BackgroundSyncStatusStore(),
);

final backgroundSyncStatusProvider =
    StreamProvider<BackgroundSyncState>((ref) async* {
  final store = ref.read(backgroundSyncStatusStoreProvider);
  yield await store.readState();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 2))) {
    yield await store.readState();
  }
});

final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return backgroundSyncService;
});

class BackgroundSyncService {
  final BackgroundSyncStatusStore _statusStore;

  static bool _initialized = false;

  BackgroundSyncService({required BackgroundSyncStatusStore statusStore})
      : _statusStore = statusStore;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Workmanager().initialize(callbackDispatcher);

    _initialized = true;
  }

  Future<void> schedulePeriodicSync(int intervalMinutes) async {
    if (intervalMinutes <= 0) {
      await cancelPeriodicSync();
      return;
    }

    final frequencyMinutes = intervalMinutes < 15 ? 15 : intervalMinutes;
    await Workmanager().registerPeriodicTask(
      _backgroundSyncUniqueName,
      _backgroundSyncTaskName,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      frequency: Duration(minutes: frequencyMinutes),
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
      inputData: const {'mode': 'periodic'},
    );
  }

  Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(_backgroundSyncUniqueName);
  }

  Future<void> markSyncing({String? message}) async {
    await _statusStore.markSyncing(message: message);
  }

  Future<void> markFinished({required bool success, String? message}) async {
    await _statusStore.markFinished(success: success, message: message);
  }

  Future<void> markIdle() async {
    await _statusStore.markIdle();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _backgroundSyncTaskName) {
      return true;
    }

    final statusStore = BackgroundSyncStatusStore();
    await statusStore.markSyncing(message: 'background sync started');

    try {
      final result = await _runBackgroundSync();
      await statusStore.markFinished(
        success: result.success,
        message: result.success ? null : result.errorMessage,
      );
      return result.success;
    } catch (e) {
      await statusStore.markFinished(success: false, message: e.toString());
      return false;
    }
  });
}

Future<SyncResult> _runBackgroundSync() async {
  final settingsService = WebDavSettingsService();
  final config = await settingsService.loadConfig();
  if (!config.isConfigured || config.syncIntervalMinutes <= 0) {
    return const SyncResult(success: true);
  }

  final coordinator = SyncCoordinator(clientWrapper: WebDavClientWrapper());
  coordinator.configure(
    baseUrl: config.baseUrl,
    username: config.username,
    password: config.password,
    remoteDir: config.remoteDir,
  );
  coordinator.setConflictStrategy(config.conflictStrategy);

  return coordinator.syncNow();
}

/// Helper used by UI code to make sure the background sync subsystem exists.
Future<void> initializeWebDavBackgroundSync() async {
  await backgroundSyncService.initialize();
}
