class PlatformNotificationItem {
  const PlatformNotificationItem({
    required this.id,
    required this.noticeType,
    required this.title,
    required this.body,
    required this.isActive,
    required this.isRead,
    required this.createdAt,
    this.actionLabel,
    this.actionUrl,
  });

  final int id;
  final String noticeType;
  final String title;
  final String body;
  final String? actionLabel;
  final String? actionUrl;
  final bool isActive;
  final bool isRead;
  final DateTime? createdAt;

  factory PlatformNotificationItem.fromJson(Map<String, dynamic> json) {
    return PlatformNotificationItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      noticeType: json['notice_type']?.toString() ?? 'message',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      actionLabel: json['action_label']?.toString(),
      actionUrl: json['action_url']?.toString(),
      isActive: json['is_active'] == true,
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
