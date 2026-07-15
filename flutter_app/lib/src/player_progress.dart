class PlayerProgress {
  const PlayerProgress({
    required this.userId,
    required this.rating,
    required this.level,
  });

  final int userId;
  final int rating;
  final int level;

  factory PlayerProgress.fromJson(Map<String, dynamic> json) => PlayerProgress(
    userId: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    rating: int.tryParse(json['rating']?.toString() ?? '') ?? 0,
    level: int.tryParse(json['level']?.toString() ?? '') ?? 0,
  );
}
