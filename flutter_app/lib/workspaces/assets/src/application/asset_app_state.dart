import 'package:flutter/widgets.dart';

import '../cloud/asset_sync_coordinator.dart';
import '../cloud/cloud_session_manager.dart';
import '../cloud/secure_session_store.dart';
import '../data/asset_repository.dart';
import '../domain/asset_models.dart';

class AssetAppState extends ChangeNotifier {
  AssetAppState(
    this.repository, [
    this._cloudSessionManager,
    this._syncCoordinator,
    this.closeRepositoryOnDispose = true,
  ]);

  final AssetRepository repository;
  final CloudSessionAccess? _cloudSessionManager;
  final AssetSyncCoordinator? _syncCoordinator;
  final bool closeRepositoryOnDispose;

  bool _loading = true;
  Object? _error;
  List<AssetItem> _assets = const [];
  List<AssetEvent> _events = const [];
  List<AssetEntityLink> _links = const [];
  List<AssetSyncConflict> _conflicts = const [];
  List<AssetSyncIssue> _syncIssues = const [];
  int _pendingSyncCount = 0;

  StoredCloudSession? _cloudSession;
  bool _syncing = false;
  Object? _syncError;
  AssetSyncSummary? _lastSyncSummary;

  bool get loading => _loading;
  Object? get error => _error;
  List<AssetItem> get assets => _assets;
  List<AssetEvent> get events => _events;
  List<AssetEntityLink> get links => _links;
  List<AssetSyncConflict> get conflicts => _conflicts;
  List<AssetSyncIssue> get syncIssues => _syncIssues;
  int get pendingSyncCount => _pendingSyncCount;
  bool get cloudAvailable => _cloudSessionManager != null && _syncCoordinator != null;
  bool get cloudConnected => _cloudSession != null;
  StoredCloudSession? get cloudSession => _cloudSession;
  bool get syncing => _syncing;
  Object? get syncError => _syncError;
  AssetSyncSummary? get lastSyncSummary => _lastSyncSummary;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _reload(notify: false);
      final manager = _cloudSessionManager;
      if (manager != null) {
        try {
          _cloudSession = await manager.currentSession();
        } catch (error) {
          _syncError = error;
        }
      }
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  AssetItem? assetById(String id) {
    for (final asset in _assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  List<AssetEvent> eventsFor(String assetId) {
    return _events
        .where((event) => event.assetId == assetId)
        .toList(growable: false);
  }

  List<AssetEntityLink> linksFor(String assetId) {
    return _links
        .where((link) => link.sourceAssetId == assetId)
        .toList(growable: false);
  }

  Future<void> saveAsset(AssetItem asset) async {
    await repository.upsertAsset(asset);
    await _reload();
  }

  Future<void> deleteAsset(String assetId) async {
    await repository.deleteAsset(assetId);
    await _reload();
  }

  Future<void> saveEvent(AssetEvent event) async {
    await repository.upsertEvent(event);
    await _reload();
  }

  Future<void> deleteEvent(String eventId) async {
    await repository.deleteEvent(eventId);
    await _reload();
  }

  Future<void> createLink({
    required String sourceAssetId,
    required String targetEntityType,
    required String targetEntityId,
    required String relationType,
    String targetLabel = '',
  }) async {
    final syncState = await repository.getSyncState();
    final userId = _cloudSession?.userId ?? syncState.boundUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('创建跨应用关联前需要先连接一次 LifeTrace Cloud');
    }

    final now = DateTime.now();
    await repository.upsertLink(
      AssetEntityLink(
        id: newEntityId('link'),
        userId: userId,
        sourceAssetId: sourceAssetId,
        targetEntityType: targetEntityType.trim(),
        targetEntityId: targetEntityId.trim(),
        relationType: relationType.trim(),
        targetLabel: targetLabel.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _reload();
  }

  Future<void> deleteLink(String linkId) async {
    await repository.deleteLink(linkId);
    await _reload();
  }

  Future<void> loginCloud({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final manager = _cloudSessionManager;
    if (manager == null) throw StateError('当前环境未启用 Cloud');
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      _cloudSession = await manager.login(
        baseUrl: baseUrl,
        email: email,
        password: password,
      );
      await _runSyncInternal();
    } catch (error) {
      _syncError = error;
      rethrow;
    } finally {
      _syncing = false;
      await _reload(notify: false);
      notifyListeners();
    }
  }

  Future<AssetSyncSummary> syncNow() async {
    if (_syncing) {
      throw StateError('同步正在进行中');
    }
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      return await _runSyncInternal();
    } catch (error) {
      _syncError = error;
      rethrow;
    } finally {
      _syncing = false;
      await _reload(notify: false);
      notifyListeners();
    }
  }

  Future<AssetSyncSummary> _runSyncInternal() async {
    final coordinator = _syncCoordinator;
    if (coordinator == null) throw StateError('当前环境未启用 Cloud');
    final summary = await coordinator.syncNow();
    _lastSyncSummary = summary;
    _cloudSession = await _cloudSessionManager?.currentSession();
    await _reload(notify: false);
    return summary;
  }

  Future<void> logoutCloud() async {
    final manager = _cloudSessionManager;
    if (manager == null) return;
    await manager.logout();
    _cloudSession = null;
    _lastSyncSummary = null;
    _syncError = null;
    notifyListeners();
  }

  Future<void> resolveConflictUseServer(String conflictId) async {
    await repository.resolveConflictUseServer(conflictId);
    await _reload();
  }

  Future<void> resolveConflictKeepLocal(String conflictId) async {
    await repository.resolveConflictKeepLocal(conflictId);
    await _reload();
  }

  Future<String> exportBackupJson() => repository.exportBackupJson();

  Future<void> importBackupJson(String raw) async {
    await repository.importBackupJson(raw);
    _cloudSession = await _cloudSessionManager?.currentSession();
    _lastSyncSummary = null;
    _syncError = null;
    await _reload();
  }

  Future<void> resetLocalData() async {
    await repository.clearAll();
    await _reload();
  }

  Future<void> retryLoad() => initialize();

  Future<void> _reload({bool notify = true}) async {
    _assets = await repository.listAssets();
    final validAssetIds = _assets.map((asset) => asset.id).toSet();
    _events = (await repository.listEvents())
        .where((event) => validAssetIds.contains(event.assetId))
        .toList(growable: false);
    _links = (await repository.listLinks())
        .where((link) => validAssetIds.contains(link.sourceAssetId))
        .toList(growable: false);
    _pendingSyncCount = await repository.pendingOutboxCount();
    _conflicts = await repository.listConflicts();
    _syncIssues = await repository.listSyncIssues();
    _error = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    if (closeRepositoryOnDispose) {
      repository.close();
    }
    super.dispose();
  }
}

class AssetScope extends InheritedNotifier<AssetAppState> {
  const AssetScope({
    required AssetAppState notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static AssetAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AssetScope>();
    assert(scope != null, 'AssetScope is missing above this context.');
    return scope!.notifier!;
  }
}
