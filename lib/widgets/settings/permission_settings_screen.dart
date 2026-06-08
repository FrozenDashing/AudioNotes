import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_i18n.dart';

/// Dedicated permission settings screen, modeled after the Chrono app pattern.
///
/// Each tile shows the current permission status and provides a button to
/// request / open the relevant system settings page.
class PermissionSettingsScreen extends StatefulWidget {
  const PermissionSettingsScreen({super.key});

  @override
  State<PermissionSettingsScreen> createState() =>
      _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen> {
  bool _notificationsAllowed = false;
  bool _batteryOptimizationIgnored = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);

    try {
      final notifAllowed = await AwesomeNotifications().isNotificationAllowed();
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

      if (mounted) {
        setState(() {
          _notificationsAllowed = notifAllowed;
          _batteryOptimizationIgnored = batteryStatus.isGranted;
          _loading = false;
        });
      }
    } catch (e) {
      foundation.debugPrint('Failed to check permission status: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.permission.title')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoHeader(context),
                const SizedBox(height: 16),
                _buildNotificationPermissionTile(context),
                const Divider(),
                _buildExactAlarmPermissionTile(context),
                const Divider(),
                _buildBatteryOptimizationTile(context),
                const Divider(),
                _buildSystemNotificationSettingsTile(context),
              ],
            ),
    );
  }

  Widget _buildInfoHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('settings.permission.description'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPermissionTile(BuildContext context) {
    return _PermissionTile(
      icon: Icons.notifications_active,
      title: context.tr('settings.permission.notification'),
      subtitle: context.tr('settings.permission.notificationDesc'),
      isGranted: _notificationsAllowed,
      onRequest: () async {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          permissions: [
            NotificationPermission.Alert,
            NotificationPermission.FullScreenIntent,
          ],
        );
        await _refreshStatus();
      },
    );
  }

  Widget _buildExactAlarmPermissionTile(BuildContext context) {
    return _PermissionTile(
      icon: Icons.alarm,
      title: context.tr('settings.permission.exactAlarm'),
      subtitle: context.tr('settings.permission.exactAlarmDesc'),
      isGranted: null, // Not easily checkable, always show as actionable
      onRequest: () async {
        await AwesomeNotifications().showAlarmPage();
      },
    );
  }

  Widget _buildBatteryOptimizationTile(BuildContext context) {
    return _PermissionTile(
      icon: Icons.battery_charging_full,
      title: context.tr('settings.permission.batteryOptimization'),
      subtitle: context.tr('settings.permission.batteryOptimizationDesc'),
      isGranted: _batteryOptimizationIgnored,
      onRequest: () async {
        final status = await Permission.ignoreBatteryOptimizations.request();
        if (mounted) {
          setState(() {
            _batteryOptimizationIgnored = status.isGranted;
          });
        }
      },
    );
  }

  Widget _buildSystemNotificationSettingsTile(BuildContext context) {
    return _PermissionTile(
      icon: Icons.settings,
      title: context.tr('settings.permission.systemSettings'),
      subtitle: context.tr('settings.permission.systemSettingsDesc'),
      isGranted: null,
      onRequest: () async {
        await openAppSettings();
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool? isGranted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isGranted == true
            ? Colors.green
            : Theme.of(context).colorScheme.primary,
        size: 32,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          if (isGranted != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isGranted == true ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isGranted == true ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isGranted == true ? '已授权' : '未授权',
                  style: TextStyle(
                    fontSize: 12,
                    color: isGranted == true ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: FilledButton.tonal(
        onPressed: onRequest,
        child: Text(
          isGranted == true ? '已开启' : '去开启',
        ),
      ),
    );
  }
}
