import 'dart:math';

import 'package:chess/chess.dart' as chess;

class ChessPuzzle {
  const ChessPuzzle({
    required this.id,
    required this.theme,
    required this.difficulty,
    required this.fen,
    required this.solutionLine,
    required this.hint,
    required this.explanation,
  });

  final String id;
  final String theme;
  final String difficulty;
  final String fen;
  final List<String> solutionLine;
  final String hint;
  final String explanation;
}

int dailyPuzzleIndex(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return (day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay) %
      chessPuzzles.length;
}

int randomPuzzleIndex(Random random, {int? excluding}) {
  if (chessPuzzles.length < 2) return 0;
  var index = random.nextInt(chessPuzzles.length);
  while (index == excluding) {
    index = random.nextInt(chessPuzzles.length);
  }
  return index;
}

ChessPuzzle generateRandomChessLesson(
  Random random, {
  String idPrefix = 'random',
}) {
  for (var attempt = 0; attempt < 8; attempt++) {
    final game = chess.Chess();
    final plies = 8 + random.nextInt(25);
    for (var ply = 0; ply < plies && !game.game_over; ply++) {
      final moves = game.moves({'asObjects': true}).cast<chess.Move>();
      if (moves.isEmpty) break;
      game.move(moves[random.nextInt(moves.length)]);
    }
    if (game.game_over) continue;

    final candidates = game.moves({'asObjects': true}).cast<chess.Move>();
    if (candidates.isEmpty) continue;
    candidates.sort(
      (a, b) => _lessonMoveScore(game, b).compareTo(_lessonMoveScore(game, a)),
    );
    final chosen = candidates.first;
    final san = game.move_to_san(chosen);
    final idea = _lessonIdea(chosen, san);
    return ChessPuzzle(
      id: '$idPrefix-${random.nextInt(1 << 32)}',
      theme: idea.theme,
      difficulty: plies < 16
          ? 'Beginner'
          : plies < 25
          ? 'Intermediate'
          : 'Advanced',
      fen: game.fen,
      solutionLine: ['${chosen.fromAlgebraic}${chosen.toAlgebraic}'],
      hint: idea.hint,
      explanation: '$san ${idea.explanation}',
    );
  }

  return chessPuzzles[random.nextInt(chessPuzzles.length)];
}

ChessPuzzle dailyChessPuzzle(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final seed = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return generateRandomChessLesson(Random(seed), idPrefix: 'daily-$seed');
}

({String theme, String hint, String explanation}) _lessonIdea(
  chess.Move move,
  String san,
) {
  if (san.endsWith('#')) {
    return (
      theme: 'Checkmate',
      hint: 'Look for a forcing move that leaves the king no escape.',
      explanation: 'delivers checkmate.',
    );
  }
  if (move.promotion != null) {
    return (
      theme: 'Promotion',
      hint: 'A pawn is close to the final rank.',
      explanation: 'promotes a pawn and creates a decisive advantage.',
    );
  }
  if (move.captured != null) {
    return (
      theme: 'Winning material',
      hint: 'Look for the most valuable safe capture.',
      explanation: 'wins material with the strongest available capture.',
    );
  }
  if (san.endsWith('+')) {
    return (
      theme: 'Forcing check',
      hint: 'Checks force the opponent to respond.',
      explanation: 'forces the king to react and keeps the initiative.',
    );
  }
  if (_generatedCenterSquares.contains(move.toAlgebraic)) {
    return (
      theme: 'Center control',
      hint: 'Improve control of the central squares.',
      explanation: 'improves central control and piece activity.',
    );
  }
  return (
    theme: 'Piece activity',
    hint: 'Find the move that places a piece on a more active square.',
    explanation: 'improves the position and prepares the next plan.',
  );
}

int _lessonMoveScore(chess.Chess game, chess.Move move) {
  final san = game.move_to_san(move);
  if (san.endsWith('#')) return 100000;
  var score = _generatedPieceValue(move.captured) * 100;
  if (move.promotion != null) score += 900;
  if (san.endsWith('+')) score += 75;
  if (_generatedCenterSquares.contains(move.toAlgebraic)) score += 20;
  return score;
}

int _generatedPieceValue(chess.PieceType? piece) {
  if (piece == chess.Chess.QUEEN) return 9;
  if (piece == chess.Chess.ROOK) return 5;
  if (piece == chess.Chess.BISHOP || piece == chess.Chess.KNIGHT) return 3;
  if (piece == chess.Chess.PAWN) return 1;
  return 0;
}

const _generatedCenterSquares = {
  'c3',
  'd3',
  'e3',
  'f3',
  'c4',
  'd4',
  'e4',
  'f4',
  'c5',
  'd5',
  'e5',
  'f5',
  'c6',
  'd6',
  'e6',
  'f6',
};

const chessPuzzles = <ChessPuzzle>[
  ChessPuzzle(
    id: 'fools-mate',
    theme: 'Checkmate',
    difficulty: 'Beginner',
    fen: 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
    solutionLine: ['d8h4'],
    hint: 'Look for a queen check along the dark diagonal.',
    explanation: 'Qh4 is checkmate because White cannot block or escape.',
  ),
  ChessPuzzle(
    id: 'scholars-mate',
    theme: 'Attack f7',
    difficulty: 'Beginner',
    fen: 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
    solutionLine: ['h5f7'],
    hint: 'The f7 pawn is defended only by the king.',
    explanation: 'Qxf7 is checkmate with support from the bishop on c4.',
  ),
  ChessPuzzle(
    id: 'back-rank-mate',
    theme: 'Back-rank mate',
    difficulty: 'Intermediate',
    fen: '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1',
    solutionLine: ['e1e8'],
    hint: 'The pawns around the king remove all escape squares.',
    explanation: 'Re8 is checkmate on the unprotected back rank.',
  ),
  ChessPuzzle(
    id: 'knight-fork',
    theme: 'Knight fork',
    difficulty: 'Intermediate',
    fen: '2q1k3/8/8/1N6/8/8/8/4K3 w - - 0 1',
    solutionLine: ['b5d6'],
    hint: 'Find a knight check that also attacks the queen.',
    explanation: 'Nd6+ forks the king on e8 and queen on c8.',
  ),
  ChessPuzzle(
    id: 'protected-capture',
    theme: 'Win the queen',
    difficulty: 'Intermediate',
    fen: '4k3/4q3/8/8/1B6/8/8/4R1K1 w - - 0 1',
    solutionLine: ['e1e7'],
    hint: 'The bishop protects a powerful rook capture.',
    explanation: 'Rxe7+ wins the queen, and the bishop protects the rook.',
  ),
  ChessPuzzle(
    id: 'promotion',
    theme: 'Pawn promotion',
    difficulty: 'Beginner',
    fen: '7k/P7/8/8/8/8/7K/8 w - - 0 1',
    solutionLine: ['a7a8'],
    hint: 'Advance the pawn to the final rank.',
    explanation: 'a8=Q promotes the pawn and creates a decisive advantage.',
  ),
  ChessPuzzle(
    id: 'open-center',
    theme: 'Opening principles',
    difficulty: 'Beginner',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    solutionLine: ['e2e4', 'e7e5', 'g1f3'],
    hint: 'Control the center, then develop a knight toward it.',
    explanation: 'e4 claims the center and Nf3 develops while attacking e5.',
  ),
  ChessPuzzle(
    id: 'queens-gambit',
    theme: 'Space advantage',
    difficulty: 'Intermediate',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    solutionLine: ['d2d4', 'd7d5', 'c2c4'],
    hint: 'Build central space and challenge Black\'s d5 pawn.',
    explanation:
        'd4 and c4 create the Queen\'s Gambit and pressure the center.',
  ),
];
