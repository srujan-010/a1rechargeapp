import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../domain/models/app_notification.dart';
import 'notifications_providers.dart';

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
    // ignore: unused_result
    ref.refresh(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final hasMore = ref.watch(notificationsProvider.notifier).hasMore;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const ListSkeleton(count: 8),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 100,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.pagePadding),
                    child: EmptyStateWidget(
                      title: 'No notifications yet.',
                      description: 'You are all caught up!',
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primaryBlue,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final notif = notifications[index];
                return _NotificationTile(notif: notif);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = notif.isRead ? AppColors.cardWhite : AppColors.primaryBlueLight.withOpacity(0.3);
    
    IconData iconData;
    Color iconColor;
    
    switch (notif.category) {
      case NotificationCategory.offer:
        iconData = Icons.local_offer;
        iconColor = AppColors.warning;
        break;
      case NotificationCategory.success:
        iconData = Icons.check_circle;
        iconColor = AppColors.success;
        break;
      case NotificationCategory.warning:
        iconData = Icons.warning;
        iconColor = Colors.orange;
        break;
      case NotificationCategory.error:
        iconData = Icons.error;
        iconColor = AppColors.error;
        break;
      case NotificationCategory.system:
        iconData = Icons.settings;
        iconColor = Colors.grey;
        break;
      case NotificationCategory.info:
      default:
        iconData = Icons.notifications;
        iconColor = AppColors.primaryBlue;
    }

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          ref.read(notificationsProvider.notifier).markAsRead(notif.id);
        }
        
        if (notif.action != null) {
          switch (notif.action) {
            case 'ROUTE_WALLET':
              context.go(RouteNames.wallet);
              break;
            case 'ROUTE_KYC':
              context.push(RouteNames.kyc);
              break;
            case 'ROUTE_PROFILE':
              context.go(RouteNames.profile);
              break;
            case 'ROUTE_HISTORY':
              context.go(RouteNames.history);
              break;
          }
        }
      },
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: AppTextTheme.textTheme.titleSmall?.copyWith(
                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(notif.timestamp),
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notif.message,
                    style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                      color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final duration = DateTime.now().difference(dt);
    if (duration.inSeconds < 60) {
      return 'Just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} mins ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} hours ago';
    } else if (duration.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${duration.inDays} days ago';
    }
  }
}