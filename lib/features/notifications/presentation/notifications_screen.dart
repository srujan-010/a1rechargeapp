import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../domain/models/app_notification.dart';
import 'notifications_providers.dart';


enum NotificationType {
  recharge,
  wallet,
  security,
  offers,
  failed,
  processing,
}

enum DateGroup { today, yesterday, earlier }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).fetchMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(notificationsProvider.notifier).refreshSilently();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.valueOrNull;

    final unreadCount = notifications?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2563EB)),
              label: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, notificationsAsync, notifications),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<AppNotification>> notificationsAsync,
    List<AppNotification>? notifications,
  ) {
    // Initial loading state (no cached data available yet)
    if (notificationsAsync.isLoading && notifications == null) {
      return const _NotificationsSkeleton();
    }

    // Error state without data
    if (notificationsAsync.hasError && notifications == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Failed to load notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.refresh(notificationsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (notifications == null || notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 44,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We will notify you here about your recharges, wallet transactions, security alerts, and exclusive offers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Grouped notifications list
    final grouped = _groupNotifications(notifications);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF2563EB),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (grouped[DateGroup.today]!.isNotEmpty)
            ..._buildGroupSliver('TODAY', grouped[DateGroup.today]!),
          if (grouped[DateGroup.yesterday]!.isNotEmpty)
            ..._buildGroupSliver('YESTERDAY', grouped[DateGroup.yesterday]!),
          if (grouped[DateGroup.earlier]!.isNotEmpty)
            ..._buildGroupSliver('EARLIER', grouped[DateGroup.earlier]!),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _buildGroupSliver(String title, List<AppNotification> items) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final notif = items[index];
              return _SwipeableNotificationCard(
                key: ValueKey(notif.id),
                notif: notif,
              );
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }
}

// ─── Swipeable Notification Card ──────────────────────────────────────────────

class _SwipeableNotificationCard extends ConsumerWidget {
  const _SwipeableNotificationCard({super.key, required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(notif.id),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swiped Right -> Mark as Read
            if (!notif.isRead) {
              ref.read(notificationsProvider.notifier).markAsRead(notif.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Marked as read'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return false; // Keep item in list
          } else if (direction == DismissDirection.endToStart) {
            // Swiped Left -> Delete
            ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification deleted'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return true; // Remove item from list
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB), // Blue
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Mark Read',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444), // Red
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
        child: _NotificationCardContent(notif: notif),
      ),
    );
  }
}

// ─── Notification Card Content ────────────────────────────────────────────────

class _NotificationCardContent extends ConsumerWidget {
  const _NotificationCardContent({required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = _getNotificationType(notif);
    final style = _NotificationStyle.fromType(type);

    final isUnread = !notif.isRead;
    final cardBgColor = isUnread ? const Color(0xFFEFF6FF) : Colors.white;
    final cardBorderColor = isUnread ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: isUnread ? 1.2 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isUnread) {
              ref.read(notificationsProvider.notifier).markAsRead(notif.id);
            }
            if (notif.action != null) {
              _handleNotificationAction(context, notif.action);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color-coded Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    style.icon,
                    color: style.iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: const Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB), // Blue unread indicator dot
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif.message,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(notif.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationAction(BuildContext context, String? action) {
    if (action == null || action.isEmpty) return;
    if (action.startsWith('/')) {
      context.push(action);
      return;
    }
    switch (action) {
      case 'ROUTE_WALLET':
        context.go(RouteNames.wallet);
        break;
      case 'ROUTE_KYC':
        context.push(RouteNames.kyc);
        break;
      case 'ROUTE_PROFILE':
        context.go(RouteNames.profileView);
        break;
      case 'ROUTE_HISTORY':
        context.go(RouteNames.transactionHistory);
        break;
      default:
        if (action.contains('transactions') || action.contains('details')) {
          context.go(RouteNames.transactionHistory);
        }
        break;
    }
  }
}

// ─── Helpers & Style Mappings ─────────────────────────────────────────────────

NotificationType _getNotificationType(AppNotification notif) {
  final title = notif.title.toLowerCase();
  final message = notif.message.toLowerCase();

  if (notif.category == NotificationCategory.error ||
      title.contains('failed') ||
      title.contains('declined') ||
      message.contains('failed') ||
      message.contains('unsuccessful')) {
    return NotificationType.failed;
  }

  if (title.contains('processing') || message.contains('processing') || message.contains('submitted')) {
    return NotificationType.processing;
  }

  if (notif.category == NotificationCategory.offer ||
      title.contains('offer') ||
      title.contains('cashback') ||
      title.contains('discount') ||
      title.contains('reward') ||
      message.contains('cashback') ||
      message.contains('coupon')) {
    return NotificationType.offers;
  }

  if (notif.category == NotificationCategory.system ||
      notif.category == NotificationCategory.warning ||
      title.contains('login') ||
      title.contains('security') ||
      title.contains('mpin') ||
      title.contains('password') ||
      title.contains('device') ||
      title.contains('alert') ||
      message.contains('session')) {
    return NotificationType.security;
  }

  if (title.contains('wallet') ||
      title.contains('credit') ||
      title.contains('debit') ||
      title.contains('add money') ||
      title.contains('topup') ||
      title.contains('balance') ||
      message.contains('wallet')) {
    return NotificationType.wallet;
  }

  return NotificationType.recharge;
}

class _NotificationStyle {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _NotificationStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  static _NotificationStyle fromType(NotificationType type) {
    switch (type) {
      case NotificationType.recharge:
        return const _NotificationStyle(
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF10B981), // Emerald Green
          iconBgColor: Color(0xFFD1FAE5),
        );
      case NotificationType.processing:
        return const _NotificationStyle(
          icon: Icons.hourglass_top_rounded,
          iconColor: Color(0xFFD97706), // Amber
          iconBgColor: Color(0xFFFEF3C7),
        );
      case NotificationType.wallet:
        return const _NotificationStyle(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: Color(0xFF2563EB), // Blue
          iconBgColor: Color(0xFFDBEAFE),
        );
      case NotificationType.security:
        return const _NotificationStyle(
          icon: Icons.shield_rounded,
          iconColor: Color(0xFFD97706), // Orange
          iconBgColor: Color(0xFFFEF3C7),
        );
      case NotificationType.offers:
        return const _NotificationStyle(
          icon: Icons.card_membership_rounded,
          iconColor: Color(0xFF7C3AED), // Purple
          iconBgColor: Color(0xFFEDE9FE),
        );
      case NotificationType.failed:
        return const _NotificationStyle(
          icon: Icons.error_outline_rounded,
          iconColor: Color(0xFFDC2626), // Red
          iconBgColor: Color(0xFFFEE2E2),
        );
    }
  }
}

Map<DateGroup, List<AppNotification>> _groupNotifications(List<AppNotification> notifications) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final Map<DateGroup, List<AppNotification>> grouped = {
    DateGroup.today: [],
    DateGroup.yesterday: [],
    DateGroup.earlier: [],
  };

  for (final notif in notifications) {
    final local = notif.timestamp.toLocal();
    final notifDayStart = DateTime(local.year, local.month, local.day);

    if (notifDayStart.isAtSameMomentAs(todayStart) || notifDayStart.isAfter(todayStart)) {
      grouped[DateGroup.today]!.add(notif);
    } else if (notifDayStart.isAtSameMomentAs(yesterdayStart)) {
      grouped[DateGroup.yesterday]!.add(notif);
    } else {
      grouped[DateGroup.earlier]!.add(notif);
    }
  }

  return grouped;
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24 && dt.day == now.day) {
    return DateFormat('h:mm a').format(dt);
  } else if (dt.day == now.subtract(const Duration(days: 1)).day) {
    return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
  } else {
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

// ─── Skeleton Loader ──────────────────────────────────────────────────────────

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 44, height: 44, borderRadius: 22),
              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: double.infinity, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}