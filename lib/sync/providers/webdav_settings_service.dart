import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../planner/sync_planner.dart';

/// Service for managing WebDAV sync settings and credentials.
class WebDavSettingsService {
  static const _baseUrlKey = 'webdav_base_url';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'webdav_password';
  static const _remoteDirKey = 'webdav_remote_dir';
  static const _autoSyncKey = 'webdav_auto_sync';
  static const _syncIntervalKey = 'webdav_sync_interval';
  static const _conflictStrategyKey = 'webdav_conflict_strategy';
  static const _syncOnStartupKey = 'webdav_sync_on_startup';

  static const _secureStorage = FlutterSecureStorage();

  /// Load WebDAV configuration
  Future<WebDavConfig> loadConfig() async {
    final baseUrl = await _secureStorage.read(key: _baseUrlKey) ?? '';
    final username = await _secureStorage.read(key: _usernameKey) ?? '';
    final password = await _secureStorage.read(key: _passwordKey) ?? '';
    final remoteDir =
        await _secureStorage.read(key: _remoteDirKey) ?? '/audionotes';
    final autoSync = await _secureStorage.read(key: _autoSyncKey);
    final syncInterval = await _secureStorage.read(key: _syncIntervalKey);
    final conflictStrategy =
        await _secureStorage.read(key: _conflictStrategyKey);
    final syncOnStartup = await _secureStorage.read(key: _syncOnStartupKey);

    return WebDavConfig(
      baseUrl: baseUrl,
      username: username,
      password: password,
      remoteDir: remoteDir,
      autoSync: autoSync == 'true',
      syncIntervalMinutes: int.tryParse(syncInterval ?? '') ?? 30,
      conflictStrategy: _parseConflictStrategy(conflictStrategy),
      syncOnStartup: syncOnStartup == 'true',
    );
  }

  /// Save WebDAV configuration
  Future<void> saveConfig(WebDavConfig config) async {
    await _secureStorage.write(key: _baseUrlKey, value: config.baseUrl);
    await _secureStorage.write(key: _usernameKey, value: config.username);
    await _secureStorage.write(key: _passwordKey, value: config.password);
    await _secureStorage.write(key: _remoteDirKey, value: config.remoteDir);
    await _secureStorage.write(
        key: _autoSyncKey, value: config.autoSync.toString());
    await _secureStorage.write(
        key: _syncIntervalKey, value: config.syncIntervalMinutes.toString());
    await _secureStorage.write(
        key: _conflictStrategyKey, value: config.conflictStrategy.name);
    await _secureStorage.write(
        key: _syncOnStartupKey, value: config.syncOnStartup.toString());
  }

  /// Clear all WebDAV configuration
  Future<void> clearConfig() async {
    await _secureStorage.delete(key: _baseUrlKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _remoteDirKey);
    await _secureStorage.delete(key: _autoSyncKey);
    await _secureStorage.delete(key: _syncIntervalKey);
    await _secureStorage.delete(key: _conflictStrategyKey);
    await _secureStorage.delete(key: _syncOnStartupKey);
  }

  /// Check if WebDAV is configured
  Future<bool> isConfigured() async {
    final baseUrl = await _secureStorage.read(key: _baseUrlKey);
    final username = await _secureStorage.read(key: _usernameKey);
    return baseUrl != null &&
        baseUrl.isNotEmpty &&
        username != null &&
        username.isNotEmpty;
  }

  ConflictStrategy _parseConflictStrategy(String? value) {
    switch (value) {
      case 'localWins':
        return ConflictStrategy.localWins;
      case 'remoteWins':
        return ConflictStrategy.remoteWins;
      case 'latestModified':
        return ConflictStrategy.latestModified;
      case 'manual':
        return ConflictStrategy.manual;
      default:
        return ConflictStrategy.latestModified;
    }
  }
}

/// WebDAV configuration model
class WebDavConfig {
  final String baseUrl;
  final String username;
  final String password;
  final String remoteDir;
  final bool autoSync;
  final int syncIntervalMinutes;
  final ConflictStrategy conflictStrategy;
  final bool syncOnStartup;

  const WebDavConfig({
    this.baseUrl = '',
    this.username = '',
    this.password = '',
    this.remoteDir = '/audionotes',
    this.autoSync = false,
    this.syncIntervalMinutes = 30,
    this.conflictStrategy = ConflictStrategy.latestModified,
    this.syncOnStartup = false,
  });

  bool get isConfigured => baseUrl.isNotEmpty && username.isNotEmpty;

  WebDavConfig copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? remoteDir,
    bool? autoSync,
    int? syncIntervalMinutes,
    ConflictStrategy? conflictStrategy,
    bool? syncOnStartup,
  }) {
    return WebDavConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDir: remoteDir ?? this.remoteDir,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
    );
  }
}
