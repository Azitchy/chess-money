class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.isOnline,
    required this.lastSeenAt,
    this.avatarUrl,
    this.rating = 0,
    this.level = 0,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? avatarUrl;
  final int rating;
  final int level;

  factory RegisteredUser.fromJson(
    Map<String, dynamic> json, {
    String? Function(String?)? resolveAvatarUrl,
  }) {
    final rawAvatarUrl = json['avatar_url']?.toString();
    return RegisteredUser(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isOnline: json['is_online'] == true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
      avatarUrl: resolveAvatarUrl == null
          ? rawAvatarUrl
          : resolveAvatarUrl(rawAvatarUrl),
      rating: int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      level: int.tryParse(json['level']?.toString() ?? '') ?? 0,
    );
  }
}
