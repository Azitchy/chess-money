class WalletConversation {
  const WalletConversation({
    required this.id,
    required this.conversationType,
    required this.subject,
    required this.amount,
    required this.status,
    required this.lastMessageAt,
    required this.messages,
    this.userName,
    this.userUsername,
    this.latestMessage,
  });

  final int id;
  final String conversationType;
  final String subject;
  final double amount;
  final String status;
  final DateTime? lastMessageAt;
  final String? userName;
  final String? userUsername;
  final List<WalletMessage> messages;
  final WalletMessage? latestMessage;

  factory WalletConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return WalletConversation(
      id: _asInt(json['id']) ?? 0,
      conversationType: json['conversation_type']?.toString() ?? 'funding',
      subject: json['subject']?.toString() ?? 'Wallet support',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'open',
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      ),
      userName: json['user'] is Map<String, dynamic>
          ? json['user']['name']?.toString()
          : null,
      userUsername: json['user'] is Map<String, dynamic>
          ? json['user']['username']?.toString()
          : null,
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map<String, dynamic>>()
                .map(WalletMessage.fromJson)
                .toList(growable: false)
          : const [],
      latestMessage: json['latest_message'] is Map<String, dynamic>
          ? WalletMessage.fromJson(
              json['latest_message'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class WalletMessage {
  const WalletMessage({
    required this.id,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.senderUsername,
    this.senderUserId,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
  });

  final int id;
  final String senderRole;
  final int? senderUserId;
  final String? senderName;
  final String? senderUsername;
  final String body;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final DateTime? createdAt;

  bool get hasAttachment => attachmentUrl != null;

  factory WalletMessage.fromJson(Map<String, dynamic> json) {
    return WalletMessage(
      id: _asInt(json['id']) ?? 0,
      senderRole: json['sender_role']?.toString() ?? 'user',
      senderUserId: _asInt(json['sender_user_id']),
      senderName: json['sender_name']?.toString(),
      senderUsername: json['sender_username']?.toString(),
      body: json['body']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      attachmentMime: json['attachment_mime']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

int? _asInt(Object? value) => int.tryParse(value?.toString() ?? '');
