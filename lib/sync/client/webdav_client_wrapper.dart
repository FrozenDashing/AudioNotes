import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' as foundation;
import 'package:webdav_client/webdav_client.dart' as webdav;

/// Wrapper around webdav_client for basic file operations on WebDAV.
class WebDavClientWrapper {
  webdav.Client? _client;
  String _baseUrl = '';
  String _username = '';
  String _remoteDir = '/audionotes';

  String get baseUrl => _baseUrl;
  String get username => _username;
  String get remoteDir => _remoteDir;

  /// Whether the client is configured (has credentials)
  bool get isConfigured => _client != null;

  /// Configure the client with new credentials
  void configure({
    required String baseUrl,
    required String username,
    required String password,
    String remoteDir = '/audionotes',
  }) {
    _baseUrl = baseUrl;
    _username = username;
    _remoteDir = remoteDir;

    _client = webdav.newClient(
      baseUrl,
      user: username,
      password: password,
      debug: false,
    );
  }

  /// Reset the client (clear credentials)
  void reset() {
    _client = null;
    _baseUrl = '';
    _username = '';
    _remoteDir = '/audionotes';
  }

  /// Ensure the remote directory structure exists
  Future<void> ensureRemoteDir() async {
    _ensureClient();
    try {
      await _client!.mkdirAll(_remoteDir);
    } catch (e) {
      foundation.debugPrint('WebDAV mkdirAll ignored: $e');
    }
  }

  /// Upload a file (write content as UTF-8 bytes)
  Future<void> uploadFile(String filename, String content) async {
    _ensureClient();
    final remotePath = '$_remoteDir/$filename';
    await _client!.write(remotePath, Uint8List.fromList(utf8.encode(content)));
  }

  /// Download a file and return its content as string (UTF-8 decoded)
  Future<String> downloadFile(String filename) async {
    _ensureClient();
    final remotePath = '$_remoteDir/$filename';
    final bytes = await _client!.read(remotePath);
    return utf8.decode(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  /// Check if a file exists on the remote
  Future<bool> fileExists(String filename) async {
    _ensureClient();
    try {
      final remotePath = '$_remoteDir/$filename';
      await _client!.readProps(remotePath);
      return true;
    } catch (e) {
      try {
        final files = await _client!.readDir(_remoteDir);
        return files.any((entry) => entry.path?.split('/').last == filename);
      } catch (innerError) {
        foundation.debugPrint('WebDAV fileExists fallback failed: $innerError');
        return false;
      }
    }
  }

  /// Delete a file from the remote
  Future<void> deleteFile(String filename) async {
    _ensureClient();
    final remotePath = '$_remoteDir/$filename';
    await _client!.remove(remotePath);
  }

  /// List files in the remote directory
  Future<List<String>> listFiles() async {
    _ensureClient();
    try {
      final list = await _client!.readDir(_remoteDir);
      return list
          .map((e) => e.path?.split('/').last ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      foundation.debugPrint('WebDAV listFiles failed: $e');
      return [];
    }
  }

  /// Test the connection by trying to list the root directory
  Future<bool> testConnection() async {
    _ensureClient();
    try {
      await _client!.readDir('/');
      return true;
    } catch (e) {
      foundation.debugPrint('WebDAV testConnection failed: $e');
      return false;
    }
  }

  void _ensureClient() {
    if (_client == null) {
      throw StateError(
          'WebDAV client is not configured. Call configure() first.');
    }
  }
}
