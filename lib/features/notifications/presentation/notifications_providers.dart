import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../data/notifications_repository_impl.dart';
import '../domain/models/app_notification.dart';
import '../domain/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(ref.watch(apiClientProvider));
});

// Provides just the unread count efficiently
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).valueOrNull;
  if (notifs == null) return 0;
  return notifs.where((n) => !n.isRead).length;
});

class NotificationsNotifier extends AutoDisposeAsyncNotifier<List<AppNotification>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  bool _isLoadingMore = false;

  @override
  Future<List<AppNotification>> build() async {
    _currentPage = 1;
    _hasMore = true;
    return _fetchNotifications();
  }

  Future<List<AppNotification>> _fetchNotifications() async {
    final repo = ref.read(notificationsRepositoryProvider);
    final result = await repo.getNotifications(page: _currentPage, limit: 20);
    return result.getOrElseCompute((e) => throw e);
  }

  Future<void> fetchMore() async {
    if (!_hasMore || _isLoadingMore) return;
    
    _isLoadingMore = true;
    _currentPage++;
    
    final repo = ref.read(notificationsRepositoryProvider);
    final result = await repo.getNotifications(page: _currentPage, limit: 20);
    
    final newItems = result.valueOrNull;
    if (newItems != null) {
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        final current = state.valueOrNull ?? [];
        state = AsyncData([...current, ...newItems]);
      }
    } else {
      _currentPage--;
    }
    _isLoadingMore = false;
  }

  Future<void> markAsRead(String id) async {
    final repo = ref.read(notificationsRepositoryProvider);
    
    // Optimistic update
    final current = state.valueOrNull;
    if (current != null) {
      final list = current.toList();
      final index = list.indexWhere((n) => n.id == id);
      if (index != -1 && !list[index].isRead) {
        list[index] = list[index].copyWith(isRead: true);
        state = AsyncData(list);
        await repo.markAsRead(id);
      }
    }
  }

  Future<void> markAllAsRead() async {
    final repo = ref.read(notificationsRepositoryProvider);
    
    final current = state.valueOrNull;
    if (current != null) {
      final list = current.map((n) => n.copyWith(isRead: true)).toList();
      state = AsyncData(list);
    }
    
    await repo.markAllAsRead();
  }
}

final notificationsProvider = AutoDisposeAsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);
