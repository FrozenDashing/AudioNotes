import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_i18n.dart';
import '../../sync/providers/sync_provider.dart';
import '../../sync/providers/webdav_settings_service.dart';
import '../../sync/coordinator/sync_coordinator.dart';
import '../../sync/planner/sync_planner.dart';
import '../../utils/motion.dart';

/// WebDAV Sync Settings Screen
class WebDavSettingsScreen extends ConsumerStatefulWidget {
  const WebDavSettingsScreen({super.key});

  @override
  ConsumerState<WebDavSettingsScreen> createState() =>
      _WebDavSettingsScreenState();
}

class _WebDavSettingsScreenState extends ConsumerState<WebDavSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remoteDirController = TextEditingController();

  bool _isTesting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final settingsService = ref.read(webdavSettingsServiceProvider);
    final config = await settingsService.loadConfig();
    if (mounted) {
      _urlController.text = config.baseUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _remoteDirController.text = config.remoteDir;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remoteDirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.sync.title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Connection Section ----
          motionEntrance(
            context,
            _SectionCard(
              icon: Icons.cloud_outlined,
              accentColor: theme.colorScheme.primary,
              title: context.tr('settings.sync.connection'),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: context.tr('settings.sync.url'),
                          hintText: 'https://dav.example.com',
                          prefixIcon: const Icon(Icons.link),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return context.tr('settings.sync.urlRequired');
                          }
                          if (!v.startsWith('http')) {
                            return context.tr('settings.sync.urlInvalid');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: context.tr('settings.sync.username'),
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return context.tr('settings.sync.usernameRequired');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: context.tr('settings.sync.password'),
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return context.tr('settings.sync.passwordRequired');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remoteDirController,
                        decoration: InputDecoration(
                          labelText: context.tr('settings.sync.remoteDir'),
                          hintText: '/audionotes',
                          prefixIcon: const Icon(Icons.folder),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(context.tr('settings.sync.testConnection')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveConfig,
                        icon: const Icon(Icons.save),
                        label: Text(context.tr('settings.sync.saveConfig')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            duration: MotionTokens.page,
          ),

          const SizedBox(height: 12),

          // ---- Sync Actions ----
          motionEntrance(
            context,
            _SectionCard(
              icon: Icons.sync,
              accentColor: theme.colorScheme.tertiary,
              title: context.tr('settings.sync.syncActions'),
              children: [
                // Manual sync button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: syncState.status == SyncStatus.syncing
                        ? null
                        : () => _doSync(),
                    icon: syncState.status == SyncStatus.syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_sync),
                    label: Text(
                      syncState.status == SyncStatus.syncing
                          ? context.tr('settings.sync.syncing')
                          : context.tr('settings.sync.syncNow'),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Disconnect button
                if (syncState.isConfigured)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _disconnect(),
                      icon: const Icon(Icons.cloud_off),
                      label: Text(context.tr('settings.sync.disconnect')),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                    ),
                  ),

                // Last sync info
                if (syncState.lastSyncTime != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: context.tr('settings.sync.lastSync'),
                    value: _formatTime(syncState.lastSyncTime!),
                  ),
                ],

                if (syncState.lastResult != null) ...[
                  _InfoRow(
                    label: context.tr('settings.sync.result'),
                    value: syncState.lastResult!.success
                        ? context.tr('settings.sync.success')
                        : '${context.tr('settings.sync.failed')}: ${syncState.lastResult!.errorMessage ?? ""}',
                  ),
                ],
              ],
            ),
            duration: MotionTokens.page,
          ),

          const SizedBox(height: 12),

          // ---- Sync Settings ----
          motionEntrance(
            context,
            _SectionCard(
              icon: Icons.settings_outlined,
              accentColor: theme.colorScheme.secondary,
              title: context.tr('settings.sync.syncSettings'),
              children: [
                // Auto sync switch
                SwitchListTile(
                  title: Text(context.tr('settings.sync.autoSync')),
                  subtitle: Text(context.tr('settings.sync.autoSyncSubtitle')),
                  value: syncState.autoSync,
                  onChanged: (v) =>
                      ref.read(syncProvider.notifier).setAutoSync(v),
                ),

                // Sync on startup
                SwitchListTile(
                  title: Text(context.tr('settings.sync.syncOnStartup')),
                  subtitle:
                      Text(context.tr('settings.sync.syncOnStartupSubtitle')),
                  value: syncState.syncOnStartup,
                  onChanged: (v) async {
                    final settingsService =
                        ref.read(webdavSettingsServiceProvider);
                    final config = await settingsService.loadConfig();
                    await settingsService
                        .saveConfig(config.copyWith(syncOnStartup: v));
                    // Reload config to apply startup sync setting
                    await ref.read(syncProvider.notifier).configureAndSave(
                          config.copyWith(syncOnStartup: v),
                        );
                  },
                ),

                const Divider(height: 1),

                // Sync interval — tap to show bottom sheet picker
                ListTile(
                  title: Text(context.tr('settings.sync.interval')),
                  subtitle: Text(
                      '${syncState.syncIntervalMinutes} ${context.tr('settings.sync.minutes')}'),
                  trailing: Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _showIntervalPicker(
                      context, syncState.syncIntervalMinutes),
                ),

                const Divider(height: 1),

                // Conflict strategy — expanded radio options
                ListTile(
                  title: Text(context.tr('settings.sync.conflictStrategy')),
                  subtitle: Text(_conflictStrategyLabel(
                      context, syncState.conflictStrategy)),
                ),
                RadioGroup<ConflictStrategy>(
                  groupValue: syncState.conflictStrategy,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(syncProvider.notifier).setConflictStrategy(v);
                    }
                  },
                  child: Column(
                    children: ConflictStrategy.values.map((strategy) {
                      return RadioListTile<ConflictStrategy>(
                        contentPadding: const EdgeInsets.only(left: 16),
                        title: Text(_conflictStrategyLabel(context, strategy)),
                        value: strategy,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            duration: MotionTokens.page,
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);
    try {
      // Temporarily configure the client for testing
      final coordinator = ref.read(syncCoordinatorProvider);
      coordinator.configure(
        baseUrl: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remoteDir: _remoteDirController.text.trim().isNotEmpty
            ? _remoteDirController.text.trim()
            : '/audionotes',
      );

      final success = await coordinator.testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? context.tr('settings.sync.connectionSuccess')
                : context.tr('settings.sync.connectionFailed')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${context.tr('settings.sync.connectionFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final syncState = ref.read(syncProvider);
    final config = WebDavConfig(
      baseUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      remoteDir: _remoteDirController.text.trim().isNotEmpty
          ? _remoteDirController.text.trim()
          : '/audionotes',
      autoSync: syncState.autoSync,
      syncIntervalMinutes: syncState.syncIntervalMinutes,
      conflictStrategy: syncState.conflictStrategy,
      syncOnStartup: syncState.syncOnStartup,
    );

    final success =
        await ref.read(syncProvider.notifier).configureAndSave(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? context.tr('settings.sync.configSaved')
              : context.tr('settings.sync.configSaveFailed')),
        ),
      );
    }
  }

  Future<void> _doSync() async {
    final result = await ref.read(syncProvider.notifier).syncNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? '${context.tr('settings.sync.syncComplete')} ↑${result.uploaded} ↓${result.downloaded}'
              : '${context.tr('settings.sync.syncFailed')}: ${result.errorMessage ?? ""}'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('settings.sync.disconnect')),
        content: Text(context.tr('settings.sync.disconnectConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('common.confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(syncProvider.notifier).disconnect();
      _urlController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _remoteDirController.text = '/audionotes';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showIntervalPicker(BuildContext context, int currentValue) {
    final theme = Theme.of(context);
    const intervals = [5, 15, 30, 60, 120];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        context.tr('settings.sync.interval'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: intervals.map((m) {
                    final selected = m == currentValue;
                    return ChoiceChip(
                      label: Text('$m ${context.tr('settings.sync.minutes')}'),
                      selected: selected,
                      onSelected: (_) {
                        ref.read(syncProvider.notifier).setSyncInterval(m);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _conflictStrategyLabel(
      BuildContext context, ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return context.tr('settings.sync.conflict.localWins');
      case ConflictStrategy.remoteWins:
        return context.tr('settings.sync.conflict.remoteWins');
      case ConflictStrategy.latestModified:
        return context.tr('settings.sync.conflict.latestModified');
      case ConflictStrategy.manual:
        return context.tr('settings.sync.conflict.manual');
    }
  }
}

/// Reusable section card widget
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Reusable info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
