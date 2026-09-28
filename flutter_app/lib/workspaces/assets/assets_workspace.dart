import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/application/asset_app_state.dart';
import 'src/cloud/asset_sync_coordinator.dart';
import 'src/cloud/cloud_session_manager.dart';
import 'src/data/asset_repository.dart';
import 'src/domain/asset_models.dart';
import 'src/domain/asset_analytics.dart';
import 'src/domain/asset_reminders.dart';
import 'src/update/app_update_service.dart';

class AssetsWorkspace extends StatefulWidget {
  const AssetsWorkspace({this.repository, super.key});

  final AssetRepository? repository;

  @override
  State<AssetsWorkspace> createState() => _AssetsWorkspaceState();
}

class _AssetsWorkspaceState extends State<AssetsWorkspace> {
  late final Future<AssetAppState> _bootstrap = _createState();

  Future<AssetAppState> _createState() async {
    final repository = widget.repository ?? await AssetRepository.open();
    final cloudSessionManager =
        widget.repository == null ? CloudSessionManager() : null;
    final syncCoordinator = cloudSessionManager == null
        ? null
        : AssetSyncCoordinator(
            repository: repository,
            sessionManager: cloudSessionManager,
          );
    final state = AssetAppState(
      repository,
      cloudSessionManager,
      syncCoordinator,
      widget.repository == null,
    );
    await state.initialize();
    return state;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetAppState>(
      future: _bootstrap,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final app = MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LifeTrace Assets',
          theme: _buildTheme(),
          home: snapshot.hasError
              ? _BootstrapError(error: snapshot.error!)
              : state == null
                  ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                  : const AssetShell(),
        );
        return state == null ? app : AssetScope(notifier: state, child: app);
      },
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_outlined, size: 42),
              const SizedBox(height: 12),
              Text('本地数据初始化失败', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _buildTheme() {
  // LifeTrace Assets: white surfaces, black hierarchy, yellow emphasis.
  const primary = Color(0xFFF5C400);
  const ink = Color(0xFF111111);
  const background = Color(0xFFF8F8F4);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: primary,
      onPrimary: ink,
      primaryContainer: const Color(0xFFFFF0A3),
      onPrimaryContainer: ink,
      secondary: ink,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF0F0EA),
      onSecondaryContainer: ink,
      tertiary: const Color(0xFFB98500),
      onTertiary: ink,
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF4F4EF),
      surfaceContainer: const Color(0xFFF2F2ED),
      outline: const Color(0xFFD2D2C8),
      outlineVariant: const Color(0xFFE6E6DF),
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFFFE071),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: ink,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: ink,
    ),
    fontFamilyFallback: const [
      'Noto Sans SC',
      'PingFang SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13, height: 1.4),
      bodySmall: TextStyle(fontSize: 11, height: 1.35),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6E6DE)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF2F2EC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}

List<AssetItem> _assets(BuildContext context) => AssetScope.of(context).assets;
List<AssetEvent> _events(BuildContext context) => AssetScope.of(context).events;

class AssetShell extends StatefulWidget {
  const AssetShell({super.key});

  @override
  State<AssetShell> createState() => _AssetShellState();
}

class _AssetShellState extends State<AssetShell> {
  int _index = 0;

  void _openAsset(AssetItem asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(asset: asset)),
    );
  }

  void _openEditor([AssetItem? asset]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetEditorScreen(asset: asset)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onOpenAsset: _openAsset,
        onAddAsset: () => _openEditor(),
        onSeeAll: () => setState(() => _index = 1),
      ),
      AssetListScreen(onOpenAsset: _openAsset, onAddAsset: () => _openEditor()),
      ActivityScreen(onOpenAsset: _openAsset),
      const AnalyticsScreen(),
      const ProfileScreen(),
    ];

    final scaffold = Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: '资产'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: '记录'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '分析'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) return scaffold;
        final height = math.min(900.0, constraints.maxHeight - 32);
        return ColoredBox(
          color: const Color(0xFFF1F1EA),
          child: Center(
            child: Container(
              width: 430,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD9D9D0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x22111111), blurRadius: 32, offset: Offset(0, 14)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: scaffold,
            ),
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.onOpenAsset,
    required this.onAddAsset,
    required this.onSeeAll,
    super.key,
  });

  final ValueChanged<AssetItem> onOpenAsset;
  final VoidCallback onAddAsset;
  final VoidCallback onSeeAll;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AssetCategory? _category;

  @override
  Widget build(BuildContext context) {
    final assets = _assets(context);
    final totalPurchase = assets.fold<double>(0, (sum, item) => sum + item.purchasePrice);
    final totalValue = assets.fold<double>(0, (sum, item) => sum + item.currentValue);
    final visible = _category == null ? assets : assets.where((e) => e.category == _category).toList();
    final reminders = buildAssetReminders(assets, now: DateTime.now());
    final expiring = reminders
        .where((reminder) => reminder.type == AssetReminderType.warranty)
        .length;
    final idleReminderCount = reminders
        .where((reminder) => reminder.type == AssetReminderType.idle)
        .length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _BrandHeader(onAddAsset: widget.onAddAsset),
              const SizedBox(height: 22),
              Text('我的资产', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('记录你拥有的一切，也记录它们为生活创造的价值', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 18),
              _SummaryPanel(
                assetCount: assets.length,
                totalPurchase: totalPurchase,
                totalValue: totalValue,
                expiringCount: expiring,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterPill(label: '全部', selected: _category == null, onTap: () => setState(() => _category = null)),
                    for (final c in AssetCategory.values.take(5)) ...[
                      const SizedBox(width: 8),
                      _FilterPill(label: c.label, selected: _category == c, onTap: () => setState(() => _category = c)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '资产概览', action: '查看全部', onTap: widget.onSeeAll),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                _EmptyPanel(
                  icon: Icons.inventory_2_outlined,
                  text: assets.isEmpty ? '还没有资产。添加第一件资产后，这里会开始计算价值、成本和保修提醒。' : '当前分类还没有资产',
                  actionLabel: assets.isEmpty ? '添加第一件资产' : null,
                  onAction: assets.isEmpty ? widget.onAddAsset : null,
                )
              else
                for (final asset in visible.take(4)) ...[
                  _AssetCard(asset: asset, onTap: () => widget.onOpenAsset(asset)),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              const _SectionHeader(title: '资产提醒'),
              const SizedBox(height: 10),
              _ReminderCard(
                icon: Icons.verified_user_outlined,
                title: '保修与维护',
                body: expiring == 0 ? '未来 90 天没有即将到期的保修' : '$expiring 件资产将在 90 天内过保，建议提前检查设备状态',
                tint: const Color(0xFFF5C400),
              ),
              const SizedBox(height: 10),
              _ReminderCard(
                icon: Icons.auto_graph_outlined,
                title: '资产复盘',
                body: idleReminderCount == 0
                    ? '当前没有标记为闲置的资产'
                    : '$idleReminderCount 件资产处于闲置状态，可以评估继续使用或出售',
                tint: const Color(0xFFD29B00),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

enum _AssetSort {
  purchaseDate('按购买时间'),
  value('按当前估值'),
  dailyCost('按日均成本'),
  retention('按保值率'),
  updatedAt('按更新时间');

  const _AssetSort(this.label);
  final String label;
}

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({required this.onOpenAsset, required this.onAddAsset, super.key});

  final ValueChanged<AssetItem> onOpenAsset;
  final VoidCallback onAddAsset;

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  final _search = TextEditingController();
  AssetStatus? _status;
  _AssetSort _sort = _AssetSort.purchaseDate;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = _assets(context).where((asset) {
      final haystack = '${asset.name} ${asset.brand} ${asset.model}'.toLowerCase();
      final matchQuery = query.isEmpty || haystack.contains(query);
      final matchStatus = _status == null || asset.status == _status;
      return matchQuery && matchStatus;
    }).toList();
    switch (_sort) {
      case _AssetSort.purchaseDate:
        items.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        break;
      case _AssetSort.value:
        items.sort((a, b) => b.currentValue.compareTo(a.currentValue));
        break;
      case _AssetSort.dailyCost:
        items.sort((a, b) => b.dailyCost.compareTo(a.dailyCost));
        break;
      case _AssetSort.retention:
        items.sort((a, b) => b.retentionRate.compareTo(a.retentionRate));
        break;
      case _AssetSort.updatedAt:
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('全部资产', style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(onPressed: widget.onAddAsset, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索资产名称、品牌或型号'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterPill(label: '全部', selected: _status == null, onTap: () => setState(() => _status = null)),
                for (final s in AssetStatus.values) ...[
                  const SizedBox(width: 8),
                  _FilterPill(label: s.label, selected: _status == s, onTap: () => setState(() => _status = s)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('共 ${items.length} 件资产', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const Spacer(),
              PopupMenuButton<_AssetSort>(
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => _AssetSort.values
                    .map((value) => PopupMenuItem(value: value, child: Text(value.label)))
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert, size: 16),
                    const SizedBox(width: 4),
                    Text(_sort.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: _EmptyPanel(
                      icon: Icons.inventory_2_outlined,
                      text: query.isEmpty && _status == null ? '还没有资产，先添加第一件资产' : '没有符合当前条件的资产',
                      actionLabel: query.isEmpty && _status == null ? '添加资产' : null,
                      onAction: query.isEmpty && _status == null ? widget.onAddAsset : null,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 18),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final asset = items[index];
                      return _AssetCard(asset: asset, onTap: () => widget.onOpenAsset(asset), compact: true);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({required this.asset, super.key});

  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    final asset = AssetScope.of(context).assetById(this.asset.id) ?? this.asset;
    final events = _events(context).where((e) => e.assetId == asset.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final links = AssetScope.of(context).linksFor(asset.id);
    final warrantyDays = asset.warrantyUntil?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产详情'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssetEditorScreen(asset: asset))),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'delete') return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('删除资产？'),
                  content: Text('“${asset.name}”及其生命周期记录将从本地视图移除，并保留同步删除记录。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('删除')),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              await AssetScope.of(context).deleteAsset(asset.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('删除资产')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AssetThumbnail(category: asset.category, size: 92),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [_CategoryBadge(asset.category), _StatusBadge(asset.status)],
                    ),
                    const SizedBox(height: 10),
                    Text(asset.spec, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _DetailMetric(label: '购买价格', value: _money(asset.purchasePrice))),
                      _VLine(),
                      Expanded(child: _DetailMetric(label: '当前估值', value: _money(asset.currentValue))),
                      _VLine(),
                      Expanded(child: _DetailMetric(label: '日均成本', value: '¥${asset.dailyCost.toStringAsFixed(2)}/天', accent: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: asset.serviceProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: const Color(0xFFE8E8E0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('已持有 ${asset.heldDays} 天', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      const Spacer(),
                      Text('保值率 ${(asset.retentionRate * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: '设备信息'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _InfoRow(label: '品牌', value: asset.brand),
                _InfoRow(label: '型号', value: asset.model),
                _InfoRow(label: '规格', value: asset.spec),
                _InfoRow(
                  label: '序列号',
                  value: _maskSensitive(asset.serialNumber),
                  trailing: asset.serialNumber.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '复制完整序列号',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: asset.serialNumber),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('完整序列号已复制')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 16),
                        ),
                ),
                _InfoRow(label: '所在位置', value: asset.location, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: '使用与保修'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _InfoRow(label: '购买日期', value: _date(asset.purchaseDate)),
                _InfoRow(
                  label: '保修截止',
                  value: asset.warrantyUntil == null ? '未记录' : _date(asset.warrantyUntil!),
                  trailing: warrantyDays == null ? null : Text(warrantyDays >= 0 ? '剩 $warrantyDays 天' : '已过保', style: TextStyle(fontSize: 11, color: warrantyDays >= 0 ? const Color(0xFF8A6A00) : Colors.red)),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: '关联内容',
            action: '添加关联',
            onTap: () => _showAddLink(context, asset),
          ),
          const SizedBox(height: 8),
          if (links.isEmpty)
            _EmptyPanel(
              icon: Icons.link_off_outlined,
              text: '还没有跨应用关联。关联只保存稳定实体类型和 ID，不会伪造其他应用的数据。',
              actionLabel: '添加关联',
              onAction: () => _showAddLink(context, asset),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < links.length; i++)
                    _EntityLinkRow(
                      link: links[i],
                      isLast: i == links.length - 1,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          _SectionHeader(title: '生命周期', action: '添加记录', onTap: () => _showAddEvent(context, asset)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const _EmptyPanel(icon: Icons.history, text: '还没有生命周期记录')
          else
            for (var i = 0; i < events.length; i++) _TimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddEvent(context, asset),
              icon: const Icon(Icons.add),
              label: const Text('添加生命周期记录'),
            ),
          ),
        ),
      ),
    );
  }
}

class AssetEditorScreen extends StatefulWidget {
  const AssetEditorScreen({this.asset, super.key});

  final AssetItem? asset;

  @override
  State<AssetEditorScreen> createState() => _AssetEditorScreenState();
}

class _AssetEditorScreenState extends State<AssetEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _spec;
  late final TextEditingController _price;
  late final TextEditingController _value;
  late final TextEditingController _purchaseChannel;
  late final TextEditingController _serialNumber;
  late final TextEditingController _location;
  late final TextEditingController _targetDailyCost;
  late DateTime _purchaseDate;
  DateTime? _warrantyUntil;
  AssetCategory _category = AssetCategory.phone;
  AssetStatus _status = AssetStatus.active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _name = TextEditingController(text: asset?.name ?? '');
    _brand = TextEditingController(text: asset?.brand ?? '');
    _model = TextEditingController(text: asset?.model ?? '');
    _spec = TextEditingController(text: asset?.spec ?? '');
    _price = TextEditingController(text: asset == null ? '' : asset.purchasePrice.toStringAsFixed(0));
    _value = TextEditingController(text: asset == null ? '' : asset.currentValue.toStringAsFixed(0));
    _purchaseChannel = TextEditingController(text: asset?.purchaseChannel ?? '');
    _serialNumber = TextEditingController(text: asset?.serialNumber ?? '');
    _location = TextEditingController(text: asset?.location ?? '');
    _targetDailyCost = TextEditingController(
      text: asset == null || asset.targetDailyCost <= 0 ? '' : asset.targetDailyCost.toStringAsFixed(2),
    );
    _purchaseDate = asset?.purchaseDate ?? DateTime.now();
    _warrantyUntil = asset?.warrantyUntil;
    _category = asset?.category ?? AssetCategory.phone;
    _status = asset?.status ?? AssetStatus.active;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _spec.dispose();
    _price.dispose();
    _value.dispose();
    _purchaseChannel.dispose();
    _serialNumber.dispose();
    _location.dispose();
    _targetDailyCost.dispose();
    super.dispose();
  }

  Future<void> _pickPurchaseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _purchaseDate = selected);
    }
  }

  Future<void> _pickWarrantyDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _warrantyUntil ?? _purchaseDate.add(const Duration(days: 365)),
      firstDate: _purchaseDate,
      lastDate: DateTime.now().add(const Duration(days: 3650 * 3)),
    );
    if (selected != null && mounted) {
      setState(() => _warrantyUntil = selected);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final value = double.tryParse(_value.text.trim());
    final targetDailyCost = double.tryParse(_targetDailyCost.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入资产名称')));
      return;
    }
    if (price == null || price < 0 || value == null || value < 0 || targetDailyCost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('价格与成本目标必须是非负数字')));
      return;
    }
    final today = DateTime.now();
    if (_purchaseDate.isAfter(DateTime(today.year, today.month, today.day))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('购买日期不能晚于今天')));
      return;
    }
    if (_warrantyUntil != null && _warrantyUntil!.isBefore(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保修截止不能早于购买日期')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final old = widget.asset;
    final asset = AssetItem(
      id: old?.id ?? newEntityId('asset'),
      name: name,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      category: _category,
      status: _status,
      purchasePrice: price,
      currentValue: value,
      purchaseDate: _purchaseDate,
      warrantyUntil: _warrantyUntil,
      spec: _spec.text.trim(),
      serialNumber: _serialNumber.text.trim(),
      location: _location.text.trim(),
      targetDailyCost: targetDailyCost,
      purchaseChannel: _purchaseChannel.text.trim(),
      maintenanceCost: old?.maintenanceCost ?? 0,
      recoveredAmount: old?.recoveredAmount ?? 0,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      serverVersion: old?.serverVersion ?? '0',
    );

    try {
      await AssetScope.of(context).saveAsset(asset);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.asset == null ? '新增资产' : '编辑资产'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
        children: [
          Container(
            height: 118,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCDCD2), style: BorderStyle.solid),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_outlined, size: 30, color: Color(0xFF5A5A5A)),
                SizedBox(height: 6),
                Text('资产图片', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('V1 暂不保存图片附件', style: TextStyle(fontSize: 11, color: Color(0xFF737373))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _FormSectionTitle('基础信息'),
          const SizedBox(height: 10),
          _Field(controller: _name, label: '名称', hint: '例如 Xiaomi 17 Pro'),
          _DropdownField<AssetCategory>(
            label: '分类',
            value: _category,
            items: AssetCategory.values,
            itemLabel: (v) => v.label,
            onChanged: (v) => setState(() => _category = v),
          ),
          _Field(controller: _brand, label: '品牌', hint: '例如 Xiaomi'),
          _Field(controller: _model, label: '型号', hint: '例如 17 Pro'),
          _Field(controller: _spec, label: '规格', hint: '例如 16GB + 512GB · 黑色'),
          _Field(controller: _location, label: '所在位置', hint: '例如 随身、书桌'),
          const SizedBox(height: 18),
          const _FormSectionTitle('购买与价值'),
          const SizedBox(height: 10),
          _Field(controller: _price, label: '购买价格', hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _Field(controller: _value, label: '当前估值', hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _Field(controller: _targetDailyCost, label: '目标日成本', hint: '可选', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _DateField(label: '购买日期', value: _date(_purchaseDate), onTap: _pickPurchaseDate),
          _Field(controller: _purchaseChannel, label: '购买渠道', hint: '例如 官方商城'),
          const SizedBox(height: 18),
          const _FormSectionTitle('设备与保修'),
          const SizedBox(height: 10),
          _Field(controller: _serialNumber, label: '序列号 / SN', hint: '可选'),
          _DateField(
            label: '保修截止',
            value: _warrantyUntil == null ? '未设置' : _date(_warrantyUntil!),
            onTap: _pickWarrantyDate,
            onClear: _warrantyUntil == null ? null : () => setState(() => _warrantyUntil = null),
          ),
          const SizedBox(height: 18),
          const _FormSectionTitle('当前状态'),
          const SizedBox(height: 10),
          _DropdownField<AssetStatus>(
            label: '资产状态',
            value: _status,
            items: AssetStatus.values,
            itemLabel: (v) => v.label,
            onChanged: (v) => setState(() => _status = v),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : widget.asset == null ? '保存资产' : '保存修改'),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({required this.onOpenAsset, super.key});

  final ValueChanged<AssetItem> onOpenAsset;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final events = [..._events(context)]..sort((a, b) => b.date.compareTo(a.date));
    final shown = _filter == '全部'
        ? events
        : events.where((event) {
            if (_filter == '购买') return event.type == AssetEventType.purchase;
            if (_filter == '维护') {
              return {
                AssetEventType.maintenance,
                AssetEventType.repair,
                AssetEventType.replacement,
              }.contains(event.type);
            }
            if (_filter == '状态') {
              return {
                AssetEventType.useStart,
                AssetEventType.lend,
                AssetEventType.returnItem,
                AssetEventType.idle,
                AssetEventType.sell,
                AssetEventType.retire,
              }.contains(event.type);
            }
            return true;
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('资产记录', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('每一次购入、维护和流转，都会成为资产的生命周期', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final label in ['全部', '购买', '维护', '状态']) ...[
                if (label != '全部') const SizedBox(width: 8),
                _FilterPill(label: label, selected: _filter == label, onTap: () => setState(() => _filter = label)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (shown.isEmpty)
          const _EmptyPanel(icon: Icons.history_outlined, text: '当前没有符合条件的生命周期记录')
        else
          for (var i = 0; i < shown.length; i++)
            Builder(
              builder: (context) {
                final event = shown[i];
                final asset = _assets(context).firstWhere((a) => a.id == event.assetId);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onOpenAsset(asset),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _GlobalTimelineRow(asset: asset, event: event, isLast: i == shown.length - 1),
                  ),
                );
              },
            ),
      ],
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final analytics = buildAssetAnalytics(
      assets: _assets(context),
      events: _events(context),
      now: DateTime.now(),
    );

    final content = switch (_tab) {
      0 => _overview(analytics),
      1 => _categories(analytics),
      2 => _costs(analytics),
      _ => _statuses(analytics),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('资产分析', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        _PillTabs(
          labels: const ['总览', '分类', '成本', '状态'],
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _overview(AssetAnalyticsSnapshot analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '资产总值',
                value: _money(analytics.totalValue),
                helper: '当前估值',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '累计购入',
                value: _money(analytics.totalPurchase),
                helper: '${analytics.assetCount} 件资产',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '总体保值率',
                value: '${analytics.retentionPercent.round()}%',
                helper: '按当前估值',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '使用中',
                value: '${analytics.countForStatus(AssetStatus.active)} 件',
                helper:
                    '闲置 ${analytics.countForStatus(AssetStatus.idle)} 件',
                icon: Icons.devices_other,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '本月变化'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniChangeCard(
                icon: Icons.add_circle_outline,
                label: '新增',
                value: '${analytics.addedThisMonth} 件',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniChangeCard(
                icon: Icons.sell_outlined,
                label: '出售',
                value: '${analytics.soldThisMonth} 件',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniChangeCard(
                icon: Icons.build_outlined,
                label: '维护',
                value: '${analytics.maintenanceThisMonth} 件',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categories(AssetAnalyticsSnapshot analytics) {
    if (analytics.assetCount == 0) {
      return const _EmptyPanel(
        icon: Icons.donut_large_outlined,
        text: '暂无资产，添加资产后会显示分类占比',
      );
    }
    final categories = analytics.categoryValues;
    return Column(
      children: [
        const _SectionHeader(title: '分类占比'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _DonutPainter(values: categories.values.toList()),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${analytics.assetCount}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '件资产',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: categories.entries.map((entry) {
                      final ratio = analytics.categoryRatio(entry.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _categoryColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${(ratio * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _costs(AssetAnalyticsSnapshot analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '累计维护',
                value: _money(analytics.totalMaintenance),
                helper: '维修 / 保养 / 配件',
                icon: Icons.build_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '累计回收',
                value: _money(analytics.totalRecovered),
                helper: '出售回收金额',
                icon: Icons.savings_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '日均成本排行'),
        const SizedBox(height: 10),
        if (analytics.dailyCostRanking.isEmpty)
          const _EmptyPanel(
            icon: Icons.calculate_outlined,
            text: '暂无资产成本数据',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < analytics.dailyCostRanking.length; i++)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      i == 0 ? 14 : 8,
                      14,
                      i == analytics.dailyCostRanking.length - 1 ? 14 : 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < 3
                                ? const Color(0xFFFFF5CC)
                                : const Color(0xFFF2F2EC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: i < 3
                                  ? const Color(0xFF8A6A00)
                                  : const Color(0xFF6B6B6B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            analytics.dailyCostRanking[i].name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '¥${analytics.dailyCostRanking[i].dailyCost.toStringAsFixed(2)}/天',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A6A00),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statuses(AssetAnalyticsSnapshot analytics) {
    if (analytics.assetCount == 0) {
      return const _EmptyPanel(
        icon: Icons.pie_chart_outline,
        text: '暂无资产，添加资产后会显示状态分布',
      );
    }
    return Column(
      children: [
        const _SectionHeader(title: '状态分布'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < AssetStatus.values.length; i++) ...[
                  _StatusDistributionRow(
                    status: AssetStatus.values[i],
                    count: analytics.countForStatus(AssetStatus.values[i]),
                    total: analytics.assetCount,
                  ),
                  if (i != AssetStatus.values.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _showLocalData(BuildContext context) async {
    final state = AssetScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地数据', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _InfoRow(label: '资产', value: '${state.assets.length} 件'),
                _InfoRow(label: '生命周期记录', value: '${state.events.length} 条'),
                _InfoRow(
                  label: '待同步变更',
                  value: '${state.pendingSyncCount} 条',
                  isLast: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('复制 JSON 备份'),
                    onPressed: () async {
                      final backup = await state.exportBackupJson();
                      await Clipboard.setData(ClipboardData(text: backup));
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('备份 JSON 已复制到剪贴板')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('从 JSON 备份恢复'),
                    onPressed: () async {
                      final controller = TextEditingController();
                      try {
                        final clipboard = await Clipboard.getData('text/plain');
                        controller.text = clipboard?.text ?? '';
                        if (!sheetContext.mounted) return;
                        final raw = await showDialog<String>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('恢复备份'),
                            content: SizedBox(
                              width: 520,
                              child: TextField(
                                controller: controller,
                                minLines: 8,
                                maxLines: 16,
                                decoration: const InputDecoration(
                                  hintText: '粘贴 LifeTrace Assets JSON 备份',
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(controller.text),
                                child: const Text('恢复'),
                              ),
                            ],
                          ),
                        );
                        if (raw == null || raw.trim().isEmpty) return;
                        await state.importBackupJson(raw);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('本地备份已恢复')),
                        );
                      } catch (error) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('恢复失败：$error')),
                          );
                        }
                      } finally {
                        controller.dispose();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清空本地数据'),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('清空本地数据？'),
                          content: const Text(
                            '这会删除当前设备上的资产、生命周期记录、同步状态和待同步队列。此操作不可撤销。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !sheetContext.mounted) return;
                      await state.resetLocalData();
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReminders(BuildContext context) async {
    final reminders = buildAssetReminders(
      AssetScope.of(context).assets,
      now: DateTime.now(),
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('资产提醒', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (reminders.isEmpty)
                const _EmptyPanel(
                  icon: Icons.notifications_none,
                  text: '当前没有需要处理的保修、闲置或维修提醒',
                )
              else
                ...reminders.take(8).map(
                  (reminder) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReminderCard(
                      icon: _reminderIcon(reminder.type),
                      title: reminder.title,
                      body: reminder.body,
                      tint: const Color(0xFFD29B00),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AssetScope.of(context);
    final cloudSubtitle = state.syncing
        ? 'LifeTrace Cloud · 正在同步…'
        : state.cloudConnected
            ? '${state.cloudSession!.email} · ${state.pendingSyncCount} 条待同步 · ${state.conflicts.length} 个冲突 · ${state.syncIssues.length} 个阻塞'
            : '未连接 Cloud · 本地数据仍可完整使用';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('我的', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFFFF5CC),
                  child: Text('L', style: TextStyle(color: Color(0xFF111111), fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LifeTrace Assets', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(cloudSubtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '数据'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.cloud_outlined,
                title: 'LifeTrace Cloud',
                subtitle: state.cloudConnected
                    ? '${state.cloudSession!.email} · ${state.conflicts.length} 个冲突 · ${state.syncIssues.length} 个阻塞'
                    : '登录后启用 Push / Pull / Snapshot / Conflict',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const _CloudSheet(),
                ),
              ),
              const _SettingsRow(
                icon: Icons.link_outlined,
                title: 'LifeTrace 关联',
                subtitle: 'V1 不伪造关联数据；EntityLink 作为后续独立 change',
              ),
              _SettingsRow(
                icon: Icons.storage_outlined,
                title: '本地数据',
                subtitle: '${state.assets.length} 件资产 · ${state.events.length} 条记录',
                isLast: true,
                onTap: () => _showLocalData(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '偏好与隐私'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.notifications_none,
                title: '提醒',
                subtitle: '保修、闲置和维修状态提醒',
                onTap: () => _showReminders(context),
              ),
              const _SettingsRow(
                icon: Icons.visibility_off_outlined,
                title: '敏感字段',
                subtitle: '详情默认遮罩；复制时使用完整原值',
              ),
              const _SettingsRow(
                icon: Icons.palette_outlined,
                title: '外观',
                subtitle: 'V1 固定白 / 黑 / 黄视觉规范',
              ),
              _SettingsRow(
                icon: Icons.info_outline,
                title: '关于 LifeTrace Assets',
                subtitle: '版本信息、项目说明与检查更新',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutAssetsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class AboutAssetsScreen extends StatefulWidget {
  const AboutAssetsScreen({super.key});

  @override
  State<AboutAssetsScreen> createState() => _AboutAssetsScreenState();
}

class _AboutAssetsScreenState extends State<AboutAssetsScreen> {
  final AppUpdateService _updateService = AppUpdateService();
  late final Future<AppVersion> _currentVersion =
      _updateService.currentVersion();
  bool _checking = false;

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) return;

      if (!result.updateAvailable) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('已是最新版本'),
            content: Text(
              '当前版本 ${result.currentVersion.display}\n'
              '最新版本 ${result.latestVersion.display}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }

      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('发现新版本'),
          content: Text(
            '当前版本 ${result.currentVersion.display}\n'
            '最新版本 ${result.latestVersion.display}\n\n'
            '可以前往 GitHub Release 下载最新 APK。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_outlined),
              label: const Text('下载更新'),
            ),
          ],
        ),
      );

      if (shouldDownload == true && mounted) {
        await _openUpdateUrl(result.preferredDownloadUrl);
      }
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('检查更新失败'),
          content: const Text(
            '暂时无法获取 GitHub Release 信息，请检查网络连接后重试。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openUpdateUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开更新下载页面')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5CC),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 36,
                      color: Color(0xFFF5C400),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'LifeTrace Assets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '个人资产全生命周期管理',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<AppVersion>(
                    future: _currentVersion,
                    builder: (context, snapshot) {
                      final version = snapshot.data;
                      return Text(
                        version == null
                            ? '版本信息读取中…'
                            : '版本 ${version.display}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(title: '版本与更新'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.system_update_alt,
                  title: '检查更新',
                  subtitle: _checking
                      ? '正在检查 GitHub Releases…'
                      : '手动检查是否有新的 Android APK',
                  isLast: true,
                  onTap: _checking ? null : _checkForUpdate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(title: '应用说明'),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'LifeTrace Assets 用于记录个人资产的购入、使用、维护、估值、出售与退役全过程。'
                '核心数据采用 Local-first 架构，并可通过 LifeTrace Cloud 同步。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF444444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSheet extends StatefulWidget {
  const _CloudSheet();

  @override
  State<_CloudSheet> createState() => _CloudSheetState();
}

class _CloudSheetState extends State<_CloudSheet> {
  final _baseUrl = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(AssetAppState state) async {
    if (_submitting) return;
    if (_baseUrl.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写 Cloud 地址、邮箱和密码')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await state.loginCloud(
        baseUrl: _baseUrl.text,
        email: _email.text,
        password: _password.text,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloud 登录/同步失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sync(AssetAppState state) async {
    try {
      final summary = await state.syncNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '同步完成：Push ${summary.pushed} · Pull ${summary.pulled} · 冲突 ${summary.conflicts}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：$error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AssetScope.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: !state.cloudAvailable
              ? const _EmptyPanel(
                  icon: Icons.cloud_off_outlined,
                  text: '当前运行环境未启用 Cloud 凭据存储；本地功能不受影响。',
                )
              : state.cloudConnected
                  ? _connected(state)
                  : _loginForm(state),
        ),
      ),
    );
  }

  Widget _loginForm(AssetAppState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('连接 LifeTrace Cloud',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Cloud 不是本地使用的前置条件。登录后会先执行 Snapshot，再 Push 本地 Outbox，最后 Pull 到最新 cursor。',
          style: TextStyle(fontSize: 11, color: Color(0xFF666666), height: 1.45),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _baseUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Cloud 地址',
            hintText: 'https://cloud.example.com',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _login(state),
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting || state.syncing ? null : () => _login(state),
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(_submitting || state.syncing ? '连接中…' : '登录并同步'),
          ),
        ),
      ],
    );
  }

  Widget _connected(AssetAppState state) {
    final session = state.cloudSession!;
    final summary = state.lastSyncSummary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LifeTrace Cloud',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    session.email,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            Icon(
              state.syncError == null
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(label: '服务', value: session.baseUrl),
        _InfoRow(
          label: '待同步',
          value: '${state.pendingSyncCount} 条',
        ),
        _InfoRow(
          label: '冲突',
          value: '${state.conflicts.length} 个',
        ),
        _InfoRow(
          label: '阻塞变更',
          value: '${state.syncIssues.length} 个',
          isLast: true,
        ),
        if (summary != null) ...[
          const SizedBox(height: 10),
          Text(
            '最近同步：Snapshot ${summary.snapshotItems} · Push ${summary.pushed} · Pull ${summary.pulled}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
          ),
        ],
        if (state.syncError != null) ...[
          const SizedBox(height: 10),
          Text(
            '最近错误：${state.syncError}',
            style: const TextStyle(fontSize: 10, color: Colors.red),
          ),
        ],
        if (state.syncIssues.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _FormSectionTitle('同步阻塞'),
          const SizedBox(height: 8),
          for (final issue in state.syncIssues)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${issue.entityType} · ${issue.entityId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.errorCode,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      issue.message,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (state.conflicts.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _FormSectionTitle('待解决冲突'),
          const SizedBox(height: 8),
          for (final conflict in state.conflicts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${conflict.entityType} · ${conflict.entityId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conflict.reason,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.syncing
                                ? null
                                : () async {
                                    await state.resolveConflictUseServer(
                                      conflict.id,
                                    );
                                  },
                            child: const Text('采用云端'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: state.syncing
                                ? null
                                : () async {
                                    await state.resolveConflictKeepLocal(
                                      conflict.id,
                                    );
                                    await _sync(state);
                                  },
                            child: const Text('保留本地'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.syncing ? null : () => _sync(state),
            icon: const Icon(Icons.sync),
            label: Text(state.syncing ? '同步中…' : '立即同步'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: state.syncing
                ? null
                : () async {
                    await state.logoutCloud();
                    if (mounted) setState(() {});
                  },
            child: const Text('退出 Cloud'),
          ),
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onAddAsset});
  final VoidCallback onAddAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LifeTrace', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            Text('记录，让生活更有迹可循', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            final count = buildAssetReminders(
              _assets(context),
              now: DateTime.now(),
            ).length;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  count == 0
                      ? '当前没有待处理资产提醒'
                      : '当前有 $count 条资产提醒，可在“我的 → 提醒”查看',
                ),
              ),
            );
          },
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 4),
        IconButton.filled(onPressed: onAddAsset, icon: const Icon(Icons.add)),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.assetCount, required this.totalPurchase, required this.totalValue, required this.expiringCount});

  final int assetCount;
  final double totalPurchase;
  final double totalValue;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD84D), Color(0xFFF5C400)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33F5C400), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryMetric(icon: Icons.inventory_2_outlined, value: '$assetCount', label: '件资产')),
          Expanded(child: _SummaryMetric(icon: Icons.payments_outlined, value: _compactMoney(totalPurchase), label: '总购入')),
          Expanded(child: _SummaryMetric(icon: Icons.account_balance_wallet_outlined, value: _compactMoney(totalValue), label: '当前估值')),
          Expanded(child: _SummaryMetric(icon: Icons.verified_user_outlined, value: '$expiringCount', label: '件即将过保')),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF111111).withValues(alpha: 0.86), size: 18),
        const SizedBox(height: 8),
        FittedBox(child: Text(value, style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 14))),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF111111).withValues(alpha: 0.68), fontSize: 9)),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFF0F3F7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF111111) : const Color(0xFF666666))),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (action != null)
          TextButton(onPressed: onTap, child: Text(action!, style: const TextStyle(fontSize: 11))),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap, this.compact = false});
  final AssetItem asset;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            children: [
              _AssetThumbnail(category: asset.category, size: compact ? 62 : 68),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                        _StatusBadge(asset.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('${asset.category.label} · ${asset.brand}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text('购入 ${_money(asset.purchasePrice)}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                        const SizedBox(width: 8),
                        Text('估值 ${_money(asset.currentValue)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('¥${asset.dailyCost.toStringAsFixed(2)}/天', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF8A6A00))),
                    if (!compact) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: asset.serviceProgress, minHeight: 4, backgroundColor: const Color(0xFFEAEAE2)),
                      ),
                      const SizedBox(height: 4),
                      Text('已使用 ${asset.heldDays} 天 · 保值率 ${(asset.retentionRate * 100).round()}%', style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9A9A9A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.category, required this.size});
  final AssetCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.25)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(_categoryIcon(category), color: color, size: size * 0.48),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == AssetStatus.active;
    final color = active ? const Color(0xFF111111) : status == AssetStatus.idle ? const Color(0xFFB98500) : const Color(0xFF6B6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(7)),
      child: Text(status.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.category);
  final AssetCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
      child: Text(category.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.icon, required this.title, required this.body, required this.tint});
  final IconData icon;
  final String title;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tint, size: 21)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF666666))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent ? const Color(0xFF8A6A00) : const Color(0xFF111111)))),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: const Color(0xFFE6E6DE));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing, this.isLast = false});
  final String label;
  final String value;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFECECE5)))),
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF666666)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final AssetEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFFFF5CC), shape: BoxShape.circle), child: Icon(_eventIcon(event.type), size: 15, color: const Color(0xFFF5C400))),
                if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE8E1BA))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_date(event.date), style: const TextStyle(fontSize: 10, color: Color(0xFF7A7A7A))),
                  const SizedBox(height: 4),
                  Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(event.detail, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalTimelineRow extends StatelessWidget {
  const _GlobalTimelineRow({required this.asset, required this.event, required this.isLast});
  final AssetItem asset;
  final AssetEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFFFF5CC), shape: BoxShape.circle), child: Icon(_eventIcon(event.type), size: 16, color: const Color(0xFFF5C400))),
                if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE4E4DC))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      _AssetThumbnail(category: asset.category, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_date(event.date), style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
                            const SizedBox(height: 3),
                            Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${asset.name} · ${event.detail}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 17, color: Color(0xFF9A9A9A)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.hint, this.keyboardType, this.prefix});
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(hintText: hint, prefixText: prefix == null ? null : '$prefix '),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: Material(
              color: const Color(0xFFF2F2EC),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
                      if (onClear != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '清除',
                          onPressed: onClear,
                          icon: const Icon(Icons.close, size: 16),
                        )
                      else
                        const Icon(Icons.calendar_today_outlined, size: 17, color: Color(0xFF666666)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.items, required this.itemLabel, required this.onChanged});
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.labels, required this.selected, required this.onChanged});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF0F3F7), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == selected ? const Color(0xFF111111) : const Color(0xFF666666))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.helper, required this.icon});
  final String label;
  final String value;
  final String helper;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 18, color: const Color(0xFFF5C400)), const Spacer(), const Icon(Icons.show_chart, size: 18, color: Color(0xFFE3B500))]),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            const SizedBox(height: 3),
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            const SizedBox(height: 3),
            Text(helper, style: const TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
          ],
        ),
      ),
    );
  }
}

class _StatusDistributionRow extends StatelessWidget {
  const _StatusDistributionRow({
    required this.status,
    required this.count,
    required this.total,
  });

  final AssetStatus status;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : count / total;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count 件 · ${(ratio * 100).round()}%',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: const Color(0xFFF0F0EA),
          ),
        ),
      ],
    );
  }
}

class _MiniChangeCard extends StatelessWidget {
  const _MiniChangeCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [Icon(icon, size: 22, color: const Color(0xFFF5C400)), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFECECE5)))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFFFF5CC), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: const Color(0xFFF5C400)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9A9A9A)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFFF4F4EE), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9A9A9A)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    const colors = [Color(0xFFF5C400), Color(0xFFD9A900), Color(0xFFE0B100), Color(0xFF4A4A4A), Color(0xFFFFE07A), Color(0xFF8A8A8A)];
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    const stroke = 18.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}

class _EntityLinkRow extends StatelessWidget {
  const _EntityLinkRow({required this.link, required this.isLast});

  final AssetEntityLink link;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final title = link.targetLabel.isEmpty ? link.targetEntityId : link.targetLabel;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEAEAE3))),
      ),
      child: ListTile(
        leading: const Icon(Icons.link_outlined, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${link.targetEntityType} · ${link.targetEntityId}\n${_relationLabel(link.relationType)}',
          style: const TextStyle(fontSize: 10.5, height: 1.35),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: '删除关联',
          icon: const Icon(Icons.link_off_outlined, size: 19),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('删除关联？'),
                content: Text('将删除与“$title”的关联，并保留同步删除记录。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await AssetScope.of(context).deleteLink(link.id);
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('删除关联失败：$error')),
              );
            }
          },
        ),
      ),
    );
  }
}

void _showAddLink(BuildContext context, AssetItem asset) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddLinkSheet(asset: asset),
  );
}

class _AddLinkSheet extends StatefulWidget {
  const _AddLinkSheet({required this.asset});

  final AssetItem asset;

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  static const _targetTypes = <String, String>{
    'execution.project': 'Execute 项目',
    'execution.task': 'Execute 任务',
    'execution.calendar_event': 'Calendar 日程',
    'execution.memo': 'Collection / Memo',
    'finance.transaction': 'Finance 交易',
    'note.note': 'Notes 笔记',
    'review.daily': 'Daily Review',
    'file.metadata': '文件',
    'asset.asset': '其他资产',
  };

  static const _relationTypes = <String, String>{
    'references': '引用',
    'belongs_to': '属于',
    'evidence_for': '作为凭证',
    'created_from': '来源于',
    'summary_of': '总结自',
  };

  String _targetEntityType = 'execution.project';
  String _relationType = 'references';
  final TextEditingController _targetId = TextEditingController();
  final TextEditingController _targetLabel = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _targetId.dispose();
    _targetLabel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final targetId = _targetId.text.trim();
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入目标实体 ID')),
      );
      return;
    }
    if (_targetEntityType == 'asset.asset' && targetId == widget.asset.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能把资产关联到它自己')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AssetScope.of(context).createLink(
        sourceAssetId: widget.asset.id,
        targetEntityType: _targetEntityType,
        targetEntityId: targetId,
        relationType: _relationType,
        targetLabel: _targetLabel.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('关联保存失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('添加跨应用关联', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.asset.name,
                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _targetEntityType,
                decoration: const InputDecoration(labelText: '目标类型'),
                items: _targetTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _targetEntityType = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetId,
                decoration: const InputDecoration(
                  labelText: '目标实体 ID',
                  hintText: '粘贴目标应用中的稳定实体 ID',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetLabel,
                decoration: const InputDecoration(
                  labelText: '显示名称（可选）',
                  hintText: '仅用于本地/关联元数据展示，不读取目标应用内容',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _relationType,
                decoration: const InputDecoration(labelText: '关联关系'),
                items: _relationTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _relationType = value);
                },
              ),
              const SizedBox(height: 10),
              const Text(
                '为了保持最小权限，Assets 只保存目标类型与 ID，不会读取 Finance / Execute / Notes 的实体正文。',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存关联'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relationLabel(String value) {
  return switch (value) {
    'belongs_to' => '属于',
    'evidence_for' => '作为凭证',
    'created_from' => '来源于',
    'summary_of' => '总结自',
    _ => '引用',
  };
}

void _showAddEvent(BuildContext context, AssetItem asset) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddEventSheet(asset: asset),
  );
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({required this.asset});

  final AssetItem asset;

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  AssetEventType _type = AssetEventType.note;
  DateTime _date = DateTime.now();
  late final TextEditingController _title = TextEditingController(text: _type.label);
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final rawAmount = _amount.text.trim();
    final amount = rawAmount.isEmpty ? null : double.tryParse(rawAmount);
    if (rawAmount.isNotEmpty && (amount == null || amount < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('金额必须是非负数字')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final event = AssetEvent(
      id: newEntityId('event'),
      assetId: widget.asset.id,
      type: _type,
      date: _date,
      title: _title.text.trim().isEmpty ? _type.label : _title.text.trim(),
      detail: _detail.text.trim(),
      amount: amount,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await AssetScope.of(context).saveEvent(event);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记录保存失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAmount = {
      AssetEventType.maintenance,
      AssetEventType.repair,
      AssetEventType.replacement,
      AssetEventType.valuation,
      AssetEventType.sell,
    }.contains(_type);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('添加资产记录', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.asset.name, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
              const SizedBox(height: 14),
              DropdownButtonFormField<AssetEventType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '记录类型'),
                items: AssetEventType.values
                    .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                    .toList(),
                onChanged: (type) {
                  if (type == null) return;
                  final oldDefault = _title.text == _type.label;
                  setState(() {
                    _type = type;
                    if (oldDefault) _title.text = type.label;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题', hintText: '例如：更换电池'),
              ),
              const SizedBox(height: 10),
              Material(
                color: const Color(0xFFF2F2EC),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  dense: true,
                  onTap: _pickDate,
                  title: const Text('发生日期', style: TextStyle(fontSize: 11)),
                  subtitle: Text(_dateFormat(_date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
              ),
              if (needsAmount) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type == AssetEventType.valuation ? '估值' : _type == AssetEventType.sell ? '回收金额' : '费用',
                    prefixText: '¥ ',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _detail,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '补充说明', hintText: '费用、渠道、状态变化等'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存记录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _eventIcon(AssetEventType type) {
  return switch (type) {
    AssetEventType.purchase => Icons.shopping_bag_outlined,
    AssetEventType.useStart => Icons.play_circle_outline,
    AssetEventType.maintenance => Icons.handyman_outlined,
    AssetEventType.repair => Icons.build_outlined,
    AssetEventType.replacement => Icons.settings_suggest_outlined,
    AssetEventType.lend => Icons.arrow_outward,
    AssetEventType.returnItem => Icons.keyboard_return,
    AssetEventType.idle => Icons.inventory_2_outlined,
    AssetEventType.valuation => Icons.auto_graph_outlined,
    AssetEventType.sell => Icons.sell_outlined,
    AssetEventType.retire => Icons.archive_outlined,
    AssetEventType.note => Icons.notes_outlined,
  };
}


IconData _reminderIcon(AssetReminderType type) {
  return switch (type) {
    AssetReminderType.warranty => Icons.verified_user_outlined,
    AssetReminderType.idle => Icons.inventory_2_outlined,
    AssetReminderType.repair => Icons.build_outlined,
  };
}

String _maskSensitive(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '未记录';
  if (normalized.length <= 4) return '••••';
  final visible = normalized.length <= 8 ? 2 : 4;
  return '${normalized.substring(0, visible)}••••${normalized.substring(normalized.length - visible)}';
}

String _money(double value) => '¥${value.toStringAsFixed(0)}';
String _compactMoney(double value) => value >= 10000 ? '¥${(value / 10000).toStringAsFixed(1)}万' : _money(value);
String _date(DateTime value) => _dateFormat(value);
String _dateFormat(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

IconData _categoryIcon(AssetCategory category) {
  return switch (category) {
    AssetCategory.phone => Icons.smartphone_outlined,
    AssetCategory.tablet => Icons.tablet_mac_outlined,
    AssetCategory.computer => Icons.laptop_mac_outlined,
    AssetCategory.wearable => Icons.watch_outlined,
    AssetCategory.audio => Icons.headphones_outlined,
    AssetCategory.camera => Icons.photo_camera_outlined,
    AssetCategory.home => Icons.home_work_outlined,
    AssetCategory.other => Icons.category_outlined,
  };
}

Color _categoryColor(AssetCategory category) {
  return switch (category) {
    AssetCategory.phone => const Color(0xFFB98500),
    AssetCategory.tablet => const Color(0xFF8A6A00),
    AssetCategory.computer => const Color(0xFF111111),
    AssetCategory.wearable => const Color(0xFF6F5900),
    AssetCategory.audio => const Color(0xFFD29B00),
    AssetCategory.camera => const Color(0xFF4D4D4D),
    AssetCategory.home => const Color(0xFF9A7300),
    AssetCategory.other => const Color(0xFF6B6B6B),
  };
}
