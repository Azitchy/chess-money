import 'dart:math';

import 'package:chess/chess.dart' as chess;

class BotDifficultyProfile {
  const BotDifficultyProfile({
    required this.searchDepth,
    required this.candidatePool,
    required this.description,
  });

  final int searchDepth;
  final int candidatePool;
  final String description;
}

class ChessBotEngine {
  ChessBotEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  static BotDifficultyProfile profileFor(String difficulty) {
    return switch (difficulty) {
      'Intermediate' => const BotDifficultyProfile(
        searchDepth: 2,
        candidatePool: 3,
        description:
            'Balanced: looks ahead, captures pieces, and blocks threats.',
      ),
      'Advanced' => const BotDifficultyProfile(
        searchDepth: 3,
        candidatePool: 1,
        description:
            'Strong: searches deeper, protects pieces, and finds tactics.',
      ),
      _ => const BotDifficultyProfile(
        searchDepth: 0,
        candidatePool: 20,
        description: 'Easy: plays relaxed, mostly random legal moves.',
      ),
    };
  }

  chess.Move chooseMove(chess.Chess game, String difficulty) {
    final moves = _orderedMoves(game);
    if (moves.isEmpty) {
      throw StateError('The bot has no legal moves.');
    }

    final profile = profileFor(difficulty);
    if (profile.searchDepth == 0) {
      return moves[_random.nextInt(moves.length)];
    }

    final scored = <({chess.Move move, int score})>[];
    for (final move in moves) {
      game.move(move);
      final score = _minimax(game, profile.searchDepth - 1, -1000000, 1000000);
      game.undo();
      scored.add((move: move, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final poolSize = min(profile.candidatePool, scored.length);
    return scored[_random.nextInt(poolSize)].move;
  }

  int _minimax(chess.Chess game, int depth, int alphaValue, int betaValue) {
    if (game.in_checkmate) {
      return game.turn == chess.Color.BLACK ? -100000 : 100000;
    }
    if (game.in_draw) return 0;
    if (depth == 0) return _evaluate(game);

    var alpha = alphaValue;
    var beta = betaValue;
    final blackToMove = game.turn == chess.Color.BLACK;
    var best = blackToMove ? -1000000 : 1000000;

    for (final move in _orderedMoves(game)) {
      game.move(move);
      final score = _minimax(game, depth - 1, alpha, beta);
      game.undo();

      if (blackToMove) {
        best = max(best, score);
        alpha = max(alpha, best);
      } else {
        best = min(best, score);
        beta = min(beta, best);
      }
      if (beta <= alpha) break;
    }
    return best;
  }

  List<chess.Move> _orderedMoves(chess.Chess game) {
    final moves = game.moves({'asObjects': true}).cast<chess.Move>();
    moves.sort(
      (a, b) => _movePriority(game, b).compareTo(_movePriority(game, a)),
    );
    return moves;
  }

  int _movePriority(chess.Chess game, chess.Move move) {
    final san = game.move_to_san(move);
    if (san.endsWith('#')) return 100000;
    var score = _pieceValue(move.captured) * 10;
    if (san.endsWith('+')) score += 60;
    if (move.promotion != null) score += 800;
    if (_centerSquares.contains(move.toAlgebraic)) score += 15;
    return score;
  }

  int _evaluate(chess.Chess game) {
    var score = 0;
    for (var rank = 1; rank <= 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = '${String.fromCharCode(97 + file)}$rank';
        final piece = game.get(square);
        if (piece == null) continue;
        var value = _pieceValue(piece.type) * 100;
        if (_centerSquares.contains(square)) value += 18;
        if (piece.type == chess.Chess.PAWN && (rank == 4 || rank == 5)) {
          value += 10;
        }
        score += piece.color == chess.Color.BLACK ? value : -value;
      }
    }

    final mobility = game.moves({'asObjects': true}).length;
    score += game.turn == chess.Color.BLACK ? mobility * 2 : -mobility * 2;
    if (game.in_check) {
      score += game.turn == chess.Color.BLACK ? -35 : 35;
    }
    return score;
  }

  int _pieceValue(chess.PieceType? piece) {
    if (piece == chess.Chess.QUEEN) return 9;
    if (piece == chess.Chess.ROOK) return 5;
    if (piece == chess.Chess.BISHOP || piece == chess.Chess.KNIGHT) return 3;
    if (piece == chess.Chess.PAWN) return 1;
    return 0;
  }
}

const _centerSquares = {
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
