import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../../l10n/app_i18n.dart';
import '../../models/notification_mode.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import 'permission_settings_screen.dart';

/// Widget for selecting notification mode.
/// Permissions are handled on a dedicated screen — this widget
/// only manages the mode selection and links to the permission page.
class NotificationModeSelector extends ConsumerStatefulWidget {
  const NotificationModeSelector({super.key});

  @override
  ConsumerState<NotificationModeSelector> createState() =>
      _NotificationModeSelectorState();
}

class _NotificationModeSelectorState
    extends ConsumerState<NotificationModeSelector> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('settings.notification.title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionSettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.security, size: 18),
                  label: Text(context.tr('settings.permission.title')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('settings.notification.current')}：${_modeLabel(context, settings.notificationMode)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              title: context.tr('settings.notification.local'),
              description: context.tr('settings.notification.permissionHint'),
              icon: Icons.notifications,
              mode: NotificationMode.local,
              currentMode: settings.notificationMode,
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              title: context.tr('settings.notification.calendar'),
              description: context.tr('settings.notification.calendar'),
              icon: Icons.calendar_today,
              mode: NotificationMode.calendar,
              currentMode: settings.notificationMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String description,
    required IconData icon,
    required NotificationMode mode,
    required NotificationMode currentMode,
  }) {
    final isSelected = mode == currentMode;

    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMode(NotificationMode mode) async {
    try {
      if (mode == NotificationMode.calendar) {
        final granted = await _requestCalendarPermission();
        if (!granted) {
          return;
        }
      }

      await ref.read(settingsProvider.notifier).setNotificationMode(mode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode == NotificationMode.local ? '已切换到本地通知' : '已切换到日历同步',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('切换失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _requestCalendarPermission() async {
    final calendarService = ref.read(calendarSyncServiceProvider);
    final permissions = await calendarService.checkPermissions();
    if (permissions == CalendarPermissionStatus.granted) {
      return true;
    }

    final requested = await calendarService.requestPermissions();
    final granted = requested == CalendarPermissionStatus.granted;
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('settings.notification.permissionDenied')),
        ),
      );
    }
    return granted;
  }

  String _modeLabel(BuildContext context, NotificationMode mode) {
    return switch (mode) {
      NotificationMode.none => context.tr('settings.notification.none'),
      NotificationMode.local =>
        '${context.tr('settings.notification.local')}（默认）',
      NotificationMode.calendar => context.tr('settings.notification.calendar'),
    };
  }
}
