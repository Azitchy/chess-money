class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.isOnline,
    required this.lastSeenAt,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final bool isOnline;
  final DateTime? lastSeenAt;

  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    return RegisteredUser(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isOnline: json['is_online'] == true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
    );
  }
}
