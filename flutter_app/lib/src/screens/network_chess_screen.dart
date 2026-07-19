import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../interactive_chess_board.dart';
import '../live_match.dart';
import '../services/api_client.dart';

class NetworkChessScreen extends StatefulWidget {
  const NetworkChessScreen({
    super.key,
    required this.apiClient,
    required this.match,
    required this.currentUserId,
  });

  final ApiClient apiClient;
  final LiveMatch match;
  final int currentUserId;

  @override
  State<NetworkChessScreen> createState() => _NetworkChessScreenState();
}

class _NetworkChessScreenState extends State<NetworkChessScreen> {
  late LiveMatch _match;
  chess.Chess _game = chess.Chess();
  Timer? _poller;
  String? _selectedSquare;
  Set<String> _legalTargets = const {};
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _error;
  bool _sending = false;
  bool _settling = false;
  bool _completionShown = false;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _rebuildGame();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  bool get _myTurn =>
      _match.status == 'active' &&
      _match.currentTurnUserId == widget.currentUserId &&
      !_sending &&
      !_game.game_over;

  String get _opponentName {
    final player = widget.currentUserId == _match.player1Id
        ? _match.playerTwo
        : _match.playerOne;
    return player?.name ?? 'Opponent';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        toolbarHeight: 52,
        title: Text('Match #${_match.id}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 14),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    child: Icon(Icons.person, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _opponentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${_match.timeControl.toUpperCase()} • Stake ${_match.betAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _myTurn
                          ? const Color(0xFFDDF8E8)
                          : const Color(0xFFE9EEF7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _myTurn ? 'Your turn' : 'Waiting',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            AspectRatio(
              aspectRatio: 1,
              child: InteractiveChessBoard(
                game: _game,
                selectedSquare: _selectedSquare,
                legalTargets: _legalTargets,
                lastMoveFrom: _lastMoveFrom,
                lastMoveTo: _lastMoveTo,
                enabled: _myTurn,
                onSquareTap: _onSquareTap,
                onMove: _submitMove,
              ),
            ),
            const SizedBox(height: 7),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Center(
              child: Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _match.moves.isEmpty
                  ? 'No moves yet.'
                  : 'Moves: ${_match.moves.map((move) => '${move.from}-${move.to}').join('  ')}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    if (_match.status == 'completed') return 'Game completed';
    if (_game.in_checkmate) return 'Checkmate';
    if (_game.in_draw) return 'Draw';
    if (_game.in_check) {
      return _myTurn ? 'Your king is in check' : 'Opponent is in check';
    }
    return _myTurn ? 'Make your move' : 'Waiting for $_opponentName';
  }

  void _rebuildGame() {
    final game = chess.Chess();
    for (final move in _match.moves) {
      game.move({
        'from': move.from,
        'to': move.to,
        'promotion': move.promotion ?? 'q',
      });
    }
    _game = game;
    if (_match.moves.isNotEmpty) {
      _lastMoveFrom = _match.moves.last.from;
      _lastMoveTo = _match.moves.last.to;
    }
  }

  Future<void> _refresh() async {
    if (_sending || !mounted) return;
    try {
      final updated = await widget.apiClient.getMatchState(_match.id);
      if (!mounted) return;
      setState(() {
        _match = updated;
        _rebuildGame();
        _error = null;
      });
      if (updated.status == 'completed') {
        await _showCompletedMatch();
        return;
      }
      await _settleIfFinished();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyAppErrorMessage(error, action: 'refresh this match');
        });
      }
    }
  }

  void _onSquareTap(String square) {
    if (!_myTurn) return;
    if (_selectedSquare != null && _legalTargets.contains(square)) {
      _submitMove(_selectedSquare!, square);
      return;
    }
    final piece = _game.get(square);
    if (piece == null || piece.color != _game.turn) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = const {};
      });
      return;
    }
    final moves = _game.moves({'square': square, 'verbose': true});
    setState(() {
      _selectedSquare = square;
      _legalTargets = moves
          .whereType<Map>()
          .map((move) => move['to'].toString())
          .toSet();
    });
  }

  Future<void> _submitMove(String from, String to) async {
    if (!_myTurn) return;
    final preview = chess.Chess();
    for (final move in _match.moves) {
      preview.move({
        'from': move.from,
        'to': move.to,
        'promotion': move.promotion ?? 'q',
      });
    }
    if (!preview.move({'from': from, 'to': to, 'promotion': 'q'})) return;

    setState(() {
      _sending = true;
      _selectedSquare = null;
      _legalTargets = const {};
    });
    try {
      final updated = await widget.apiClient.submitMove(
        _match.id,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _match = updated;
        _rebuildGame();
        _error = null;
      });
      await _settleIfFinished();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyAppErrorMessage(error, action: 'submit your move');
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _settleIfFinished() async {
    if (_settling || _match.status != 'active' || !_game.game_over) return;
    _settling = true;
    final result = _game.in_checkmate
        ? (_game.turn == chess.Color.BLACK ? 'player1_win' : 'player2_win')
        : 'draw';
    try {
      final confirmed = await widget.apiClient.endMatch(_match.id, result);
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _settling = false;
          _error = 'Game finished. Waiting for opponent confirmation…';
        });
        return;
      }
      final won =
          (result == 'player1_win' &&
              widget.currentUserId == _match.player1Id) ||
          (result == 'player2_win' && widget.currentUserId == _match.player2Id);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            won
                ? 'You won!'
                : result == 'draw'
                ? 'Draw'
                : 'Game over',
          ),
          content: Text(
            won
                ? 'Congratulations! Rating +1 and Level +1. Your winnings were added to your wallet. Thank you!'
                : result == 'draw'
                ? 'Your stake has been returned to your wallet.'
                : 'The match stake was awarded to the winner.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Home'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyAppErrorMessage(
            error,
            action: 'confirm the match result',
          );
        });
      }
      await _refresh();
      if (_match.status == 'completed' && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _showCompletedMatch() async {
    if (_completionShown || !mounted) return;
    _completionShown = true;
    final won = _match.winnerId == widget.currentUserId;
    final draw = _match.winnerId == null;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          won
              ? 'You won!'
              : draw
              ? 'Draw'
              : 'Game over',
        ),
        content: Text(
          won
              ? 'Congratulations! Rating +1 and Level +1. Your winnings were added to your wallet. Thank you!'
              : draw
              ? 'Your stake has been returned to your wallet.'
              : 'The match stake was awarded to the winner.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Home'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }
}
