class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.avatarUrl,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String phoneNumber;
  final String address;
  final String? avatarUrl;

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    String? Function(String?)? resolveAvatarUrl,
  }) {
    final rawAvatarUrl = json['avatar_url']?.toString();
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      avatarUrl: resolveAvatarUrl == null
          ? rawAvatarUrl
          : resolveAvatarUrl(rawAvatarUrl),
    );
  }
}
