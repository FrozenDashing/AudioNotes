import '../serializer/todo_sync_dto.dart';

/// Conflict resolution strategy
enum ConflictStrategy {
  localWins,
  remoteWins,
  latestModified,
  manual,
}

/// Sync action to take for a single entity
enum SyncAction {
  none, // No change needed
  upload, // Local is newer/different → upload to remote
  download, // Remote is newer/different → download to local
  conflict, // Both changed since baseline → needs resolution
  deleteLocal, // Remote has deleted → delete locally
  deleteRemote, // Local has deleted → delete from remote
}

/// A planned action for one entity
class SyncPlanItem {
  final String entityId;
  final String entityType; // 'todo', 'category', 'tag', 'reminder'
  final SyncAction action;
  final ConflictStrategy? conflictStrategy;
  final TodoSyncDto? localDto;
  final TodoSyncDto? remoteDto;

  const SyncPlanItem({
    required this.entityId,
    required this.entityType,
    required this.action,
    this.conflictStrategy,
    this.localDto,
    this.remoteDto,
  });

  @override
  String toString() => 'SyncPlanItem($entityType/$entityId: $action)';
}

/// Result of sync planning
class SyncPlan {
  final List<SyncPlanItem> items;
  final int uploadCount;
  final int downloadCount;
  final int conflictCount;
  final int deleteCount;

  const SyncPlan({
    required this.items,
    this.uploadCount = 0,
    this.downloadCount = 0,
    this.conflictCount = 0,
    this.deleteCount = 0,
  });

  bool get hasConflicts => conflictCount > 0;
  bool get isEmpty => items.every((i) => i.action == SyncAction.none);
}

/// Plans sync actions by comparing local, remote, and baseline states.
class SyncPlanner {
  ConflictStrategy defaultStrategy;

  SyncPlanner({this.defaultStrategy = ConflictStrategy.latestModified});

  /// Update the default conflict strategy
  void setDefaultStrategy(ConflictStrategy strategy) {
    defaultStrategy = strategy;
  }

  /// Plan sync for a single entity type.
  /// Returns a list of planned actions.
  SyncPlan planSync<T>({
    required Map<String, T> local,
    required Map<String, T> remote,
    required Map<String, String> baselineHashes,
    required String Function(T) hashFn,
    required String entityType,
    int? Function(T)? updatedAtFn,
    ConflictStrategy? strategy,
    required bool hasEverCompletedSync,
  }) {
    final effectiveStrategy = strategy ?? defaultStrategy;
    final allIds = <String>{...local.keys, ...remote.keys};
    final items = <SyncPlanItem>[];
    int uploadCount = 0;
    int downloadCount = 0;
    int conflictCount = 0;
    int deleteCount = 0;

    for (final id in allIds) {
      final localItem = local[id];
      final remoteItem = remote[id];
      final baselineHash = baselineHashes[id];

      final localHash = localItem != null ? hashFn(localItem) : null;
      final remoteHash = remoteItem != null ? hashFn(remoteItem) : null;

      // Both exist
      if (localItem != null && remoteItem != null) {
        // Same content → no action
        if (localHash == remoteHash) {
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.none,
          ));
          continue;
        }

        // Check if only one side changed since baseline
        final localChanged = localHash != baselineHash;
        final remoteChanged = remoteHash != baselineHash;

        if (localChanged && !remoteChanged) {
          // Only local changed → upload
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.upload,
            localDto: localItem is TodoSyncDto ? localItem : null,
            remoteDto: remoteItem is TodoSyncDto ? remoteItem : null,
          ));
          uploadCount++;
        } else if (!localChanged && remoteChanged) {
          // Only remote changed → download
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.download,
            localDto: localItem is TodoSyncDto ? localItem : null,
            remoteDto: remoteItem is TodoSyncDto ? remoteItem : null,
          ));
          downloadCount++;
        } else {
          // Both changed → conflict
          SyncAction resolvedAction;
          switch (effectiveStrategy) {
            case ConflictStrategy.localWins:
              resolvedAction = SyncAction.upload;
              uploadCount++;
              break;
            case ConflictStrategy.remoteWins:
              resolvedAction = SyncAction.download;
              downloadCount++;
              break;
            case ConflictStrategy.latestModified:
              final localUpdated = updatedAtFn?.call(localItem);
              final remoteUpdated = updatedAtFn?.call(remoteItem);
              if (localUpdated != null && remoteUpdated != null) {
                if (localUpdated >= remoteUpdated) {
                  resolvedAction = SyncAction.upload;
                  uploadCount++;
                } else {
                  resolvedAction = SyncAction.download;
                  downloadCount++;
                }
              } else {
                resolvedAction = SyncAction.conflict;
                conflictCount++;
              }
              break;
            case ConflictStrategy.manual:
              resolvedAction = SyncAction.conflict;
              conflictCount++;
              break;
          }

          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: resolvedAction,
            conflictStrategy: effectiveStrategy,
            localDto: localItem is TodoSyncDto ? localItem : null,
            remoteDto: remoteItem is TodoSyncDto ? remoteItem : null,
          ));
        }
      }
      // Only local exists
      else if (localItem != null && remoteItem == null) {
        if (baselineHash != null) {
          // Was on remote before → remote deleted it
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.deleteLocal,
          ));
          deleteCount++;
        } else {
          // Never been on remote → upload
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.upload,
            localDto: localItem is TodoSyncDto ? localItem : null,
          ));
          uploadCount++;
        }
      }
      // Only remote exists
      else if (localItem == null && remoteItem != null) {
        if (baselineHash != null && hasEverCompletedSync) {
          // Was local before → local deleted it (or cascade-deleted)
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.deleteRemote,
            remoteDto: remoteItem is TodoSyncDto ? remoteItem : null,
          ));
          deleteCount++;
        } else {
          // Never been local → download
          items.add(SyncPlanItem(
            entityId: id,
            entityType: entityType,
            action: SyncAction.download,
            remoteDto: remoteItem is TodoSyncDto ? remoteItem : null,
          ));
          downloadCount++;
        }
      }
    }

    return SyncPlan(
      items: items,
      uploadCount: uploadCount,
      downloadCount: downloadCount,
      conflictCount: conflictCount,
      deleteCount: deleteCount,
    );
  }
}
