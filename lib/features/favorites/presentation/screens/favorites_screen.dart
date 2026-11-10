// Author: ThaiQHCE181542 - Quách Hoàng Thái
// UC-086: Local Data & Responsive - View Recently Viewed Events & Clear All Favorites
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/event_categories.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../local/dao/recent_view_dao.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../viewmodels/favorite_view_model.dart';

/// Màn hình danh sách sự kiện yêu thích của người dùng (UC-026, UC-082, UC-086).
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(favoriteEventsProvider);
    ref.invalidate(favoriteIdsProvider);
    ref.invalidate(recentlyViewedEventsProvider);
    await ref.read(favoriteEventsProvider.future);
  }

  List<EventModel> _applyFilters(List<EventModel> events) {
    return events.where((event) {
      // Category filter
      if (_selectedCategory != 'all' && event.category != _selectedCategory) {
        return false;
      }
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = event.title.toLowerCase().contains(query);
        final matchesDesc = event.description.toLowerCase().contains(query);
        final matchesLocation = event.locationName.toLowerCase().contains(query);
        if (!matchesTitle && !matchesDesc && !matchesLocation) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _removeSingleFavorite(EventModel event) async {
    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) return;

    await ref.read(favoriteRepositoryProvider).removeFavorite(
      userId: identity.uid,
      eventId: event.id,
    );
    ref.invalidate(favoriteIdsProvider);
    ref.invalidate(favoriteEventsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã bỏ yêu thích "${event.title}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () async {
              await ref.read(favoriteRepositoryProvider).toggleFavorite(
                userId: identity.uid,
                eventId: event.id,
                isFavorite: true,
              );
              ref.invalidate(favoriteIdsProvider);
              ref.invalidate(favoriteEventsProvider);
            },
          ),
        ),
      );
    }
  }

  Future<void> _showClearAllFavoritesDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa tất cả yêu thích?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ sự kiện đã lưu khỏi danh sách yêu thích không? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final identity = ref.read(authStateProvider).asData?.value;
      if (identity == null) return;
      await ref.read(favoriteRepositoryProvider).clearAllFavorites(identity.uid);
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(favoriteEventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ sự kiện yêu thích')),
        );
      }
    }
  }

  Future<void> _showClearRecentViewsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa lịch sử xem?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ danh sách các sự kiện đã xem gần đây không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xóa lịch sử'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final identity = ref.read(authStateProvider).asData?.value;
      if (identity == null) return;
      await ref.read(recentViewDaoProvider).clearForUser(identity.uid);
      ref.invalidate(recentlyViewedEventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa lịch sử sự kiện đã xem')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteEventsProvider);
    final hasFavorites = favoritesAsync.asData?.value.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự Kiện Yêu Thích'),
        actions: [
          if (hasFavorites && _tabController.index == 0)
            IconButton(
              key: const Key('clear-all-favorites'),
              tooltip: 'Xóa tất cả yêu thích',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _showClearAllFavoritesDialog,
            ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.favorite_rounded, size: 18),
              text: 'Yêu thích',
            ),
            Tab(
              icon: Icon(Icons.history_rounded, size: 18),
              text: 'Đã xem gần đây',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFavoritesTab(context, favoritesAsync),
          _buildRecentlyViewedTab(context),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(
    BuildContext context,
    AsyncValue<List<EventModel>> favoritesAsync,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return favoritesAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang tải danh sách yêu thích...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'Không thể tải danh sách yêu thích',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return _buildEmptyFavorites(context);
        }

        final filteredEvents = _applyFilters(events);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Search & Filter header ─────────────────────────────
                    _buildSearchAndFilters(events),
                    const SizedBox(height: 16),

                    // ── Results summary ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Đã lưu ${events.length} sự kiện'
                            '${filteredEvents.length != events.length ? ' (tìm thấy ${filteredEvents.length})' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_selectedCategory != 'all' || _searchQuery.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'all';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Xóa bộ lọc'),
                          ),
                        TextButton.icon(
                          key: const Key('clear-all-favorites-btn'),
                          onPressed: _showClearAllFavoritesDialog,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Xóa tất cả',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Events grid or empty filtered state ────────────────
                    if (filteredEvents.isEmpty)
                      _buildEmptyFilteredResults(context)
                    else
                      _buildEventsGrid(filteredEvents),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentlyViewedTab(BuildContext context) {
    final recentAsync = ref.watch(recentlyViewedEventsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return recentAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang tải lịch sử xem...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'Không thể tải lịch sử xem',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(recentlyViewedEventsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return _buildEmptyRecentlyViewed(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentlyViewedEventsProvider);
            await ref.read(recentlyViewedEventsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã xem ${events.length} sự kiện gần đây',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('clear-recent-views-btn'),
                          onPressed: _showClearRecentViewsDialog,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Xóa lịch sử'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRecentEventsGrid(events),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(List<EventModel> events) {
    final availableCategories = {'all', ...events.map((e) => e.category)};

    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm trong sự kiện yêu thích...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 12),

        // Category filter chips
        if (availableCategories.length > 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final label = category == 'all'
                    ? 'Tất cả (${events.length})'
                    : '${EventCategories.label(category)} (${events.where((e) => e.category == category).length})';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'all';
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEventsGrid(List<EventModel> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (event) => SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EventCard(
                        key: ValueKey('fav-${event.id}'),
                        event: event,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey('remove-fav-${event.id}'),
                          onPressed: () => _removeSingleFavorite(event),
                          icon: const Icon(
                            Icons.heart_broken_outlined,
                            size: 15,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Bỏ yêu thích',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentEventsGrid(List<EventModel> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (event) => SizedBox(
                  width: width,
                  child: EventCard(
                    key: ValueKey('recent-${event.id}'),
                    event: event,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyFavorites(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có sự kiện yêu thích',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn vào biểu tượng trái tim trên các sự kiện để lưu và dễ dàng theo dõi lại tại đây bất cứ lúc nào.',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(RouteNames.events),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Khám phá sự kiện ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentlyViewed(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 64,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có sự kiện đã xem gần đây',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Các sự kiện bạn mở xem chi tiết trên CampusHub sẽ được tự động lưu tại đây để bạn có thể xem lại nhanh chóng bất cứ lúc nào.',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(RouteNames.events),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Khám phá sự kiện ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredResults(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy sự kiện phù hợp',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Thử thay đổi từ khóa tìm kiếm hoặc chọn danh mục khác.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'all';
                _searchController.clear();
              });
            },
            child: const Text('Xóa bộ lọc'),
          ),
        ],
      ),
    );
  }
}
