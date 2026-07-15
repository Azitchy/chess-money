class MatchPlayer {
  const MatchPlayer({
    required this.id,
    required this.name,
    required this.username,
  });

  final int id;
  final String name;
  final String username;

  factory MatchPlayer.fromJson(Map<String, dynamic> json) => MatchPlayer(
    id: _asInt(json['id']) ?? 0,
    name: json['name']?.toString() ?? 'Player',
    username: json['username']?.toString() ?? 'player',
  );
}

class LiveMove {
  const LiveMove({required this.from, required this.to, this.promotion});

  final String from;
  final String to;
  final String? promotion;

  factory LiveMove.fromJson(Map<String, dynamic> json) => LiveMove(
    from: json['from']?.toString() ?? '',
    to: json['to']?.toString() ?? '',
    promotion: json['promotion']?.toString(),
  );
}

class LiveMatch {
  const LiveMatch({
    required this.id,
    required this.player1Id,
    required this.status,
    required this.mode,
    required this.betAmount,
    required this.timeControl,
    required this.moves,
    this.challengedUserId,
    this.player2Id,
    this.winnerId,
    this.currentTurnUserId,
    this.playerOne,
    this.playerTwo,
    this.acceptedAt,
  });

  final int id;
  final int player1Id;
  final int? challengedUserId;
  final int? player2Id;
  final int? winnerId;
  final int? currentTurnUserId;
  final String status;
  final String mode;
  final double betAmount;
  final String timeControl;
  final List<LiveMove> moves;
  final MatchPlayer? playerOne;
  final MatchPlayer? playerTwo;
  final DateTime? acceptedAt;

  factory LiveMatch.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['moves'];
    return LiveMatch(
      id: _asInt(json['id']) ?? 0,
      player1Id: _asInt(json['player_1_id']) ?? 0,
      challengedUserId: _asInt(json['challenged_user_id']),
      player2Id: _asInt(json['player_2_id']),
      winnerId: _asInt(json['winner_id']),
      currentTurnUserId: _asInt(json['current_turn_user_id']),
      status: json['status']?.toString() ?? 'pending',
      mode: json['mode']?.toString() ?? 'casual',
      betAmount: double.tryParse(json['bet_amount']?.toString() ?? '') ?? 0,
      timeControl: json['time_control']?.toString() ?? 'blitz',
      moves: rawMoves is List
          ? rawMoves
                .whereType<Map<String, dynamic>>()
                .map(LiveMove.fromJson)
                .toList(growable: false)
          : const [],
      playerOne: _player(json['player_one']),
      playerTwo: _player(json['player_two']),
      acceptedAt: DateTime.tryParse(json['accepted_at']?.toString() ?? ''),
    );
  }
}

MatchPlayer? _player(Object? value) {
  if (value is Map<String, dynamic>) return MatchPlayer.fromJson(value);
  return null;
}

int? _asInt(Object? value) => int.tryParse(value?.toString() ?? '');
