class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.status,
    required this.mode,
    required this.betAmount,
    required this.winnerId,
  });

  final int id;
  final String status;
  final String mode;
  final num betAmount;
  final int? winnerId;

  factory MatchSummary.fromJson(Map<String, dynamic> json) {
    return MatchSummary(
      id: (json['id'] as num).toInt(),
      status: json['status']?.toString() ?? 'unknown',
      mode: json['mode']?.toString() ?? 'unknown',
      betAmount: (json['bet_amount'] as num?) ?? 0,
      winnerId: (json['winner_id'] as num?)?.toInt(),
    );
  }
}
