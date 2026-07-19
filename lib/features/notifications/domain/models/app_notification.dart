// lib/features/notifications/domain/models/app_notification.dart
import 'package:equatable/equatable.dart';

enum NotificationCategory {
  success,
  info,
  warning,
  error,
  offer,
  system,
}

enum NotificationPriority {
  low,
  normal,
  high,
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.isRead,
    required this.timestamp,
    this.action,
    this.actionData,
  });

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationPriority priority;
  final bool isRead;
  final DateTime timestamp;
  final String? action;
  final Map<String, dynamic>? actionData;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        category: _parseCategory(json['category'] as String?),
        priority: _parsePriority(json['priority'] as String?),
        isRead: json['isRead'] as bool? ?? false,
        timestamp: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String).toLocal()
            : DateTime.now(),
        action: json['action'] as String?,
        actionData: json['actionData'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'title': title,
        'message': message,
        'category': category.name.toUpperCase(),
        'priority': priority.name.toUpperCase(),
        'isRead': isRead,
        'createdAt': timestamp.toUtc().toIso8601String(),
        'action': action,
        'actionData': actionData,
      };

  static NotificationCategory _parseCategory(String? raw) {
    if (raw == null) return NotificationCategory.info;
    switch (raw.toUpperCase()) {
      case 'SUCCESS': return NotificationCategory.success;
      case 'WARNING': return NotificationCategory.warning;
      case 'ERROR': return NotificationCategory.error;
      case 'OFFER': return NotificationCategory.offer;
      case 'SYSTEM': return NotificationCategory.system;
      default: return NotificationCategory.info;
    }
  }

  static NotificationPriority _parsePriority(String? raw) {
    if (raw == null) return NotificationPriority.normal;
    switch (raw.toUpperCase()) {
      case 'LOW': return NotificationPriority.low;
      case 'HIGH': return NotificationPriority.high;
      default: return NotificationPriority.normal;
    }
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        category: category,
        priority: priority,
        isRead: isRead ?? this.isRead,
        timestamp: timestamp,
        action: action,
        actionData: actionData,
      );

  @override
  List<Object?> get props =>
      [id, title, message, category, priority, isRead, timestamp, action, actionData];
}
