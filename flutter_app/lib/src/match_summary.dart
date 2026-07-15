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
    final rawBetAmount = json['bet_amount'];
    return MatchSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'unknown',
      mode: json['mode']?.toString() ?? 'unknown',
      betAmount: rawBetAmount is num
          ? rawBetAmount
          : num.tryParse(rawBetAmount?.toString() ?? '') ?? 0,
      winnerId: int.tryParse(json['winner_id']?.toString() ?? ''),
    );
  }
}
