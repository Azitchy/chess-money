import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

class InteractiveChessBoard extends StatelessWidget {
  const InteractiveChessBoard({
    super.key,
    required this.game,
    required this.selectedSquare,
    required this.legalTargets,
    required this.onSquareTap,
    required this.onMove,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.enabled = true,
  });

  final chess.Chess game;
  final String? selectedSquare;
  final Set<String> legalTargets;
  final ValueChanged<String> onSquareTap;
  final void Function(String from, String to) onMove;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return GridView.builder(
            key: const Key('interactive-chess-board'),
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (context, index) {
              final row = index ~/ 8;
              final column = index % 8;
              final square = '${String.fromCharCode(97 + column)}${8 - row}';
              final piece = game.get(square);
              final isLight = (row + column).isEven;
              final isSelected = selectedSquare == square;
              final isLastMove = lastMoveFrom == square || lastMoveTo == square;
              final isLegalTarget = legalTargets.contains(square);
              final canDrag = enabled && piece?.color == game.turn;

              return DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  return legalTargets.contains(square) &&
                      details.data == selectedSquare;
                },
                onAcceptWithDetails: (details) => onMove(details.data, square),
                builder: (context, candidates, rejected) {
                  final background = isSelected
                      ? const Color(0xFFF6D365)
                      : isLastMove
                      ? const Color(0xFFD6E76B)
                      : isLight
                      ? const Color(0xFFF0D9B5)
                      : const Color(0xFF7FA35A);

                  Widget pieceWidget = piece == null
                      ? const SizedBox.shrink()
                      : _ChessPiece(piece: piece, size: squareSize * 0.84);
                  if (piece != null && canDrag) {
                    pieceWidget = Draggable<String>(
                      data: square,
                      onDragStarted: () => onSquareTap(square),
                      feedback: Material(
                        color: Colors.transparent,
                        child: _ChessPiece(
                          piece: piece,
                          size: squareSize * 0.94,
                          shadow: true,
                        ),
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      child: pieceWidget,
                    );
                  }

                  return GestureDetector(
                    key: Key('square-$square'),
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onSquareTap(square) : null,
                    child: ColoredBox(
                      color: background,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isLegalTarget && piece == null)
                            Container(
                              width: squareSize * 0.25,
                              height: squareSize * 0.25,
                              decoration: const BoxDecoration(
                                color: Color(0x66000000),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (isLegalTarget && piece != null)
                            Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x77000000),
                                  width: 4,
                                ),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: KeyedSubtree(
                              key: ValueKey(
                                '${piece?.color}-${piece?.type}-$square',
                              ),
                              child: pieceWidget,
                            ),
                          ),
                          if (column == 0)
                            Positioned(
                              left: 3,
                              top: 2,
                              child: Text(
                                '${8 - row}',
                                style: TextStyle(
                                  color: isLight
                                      ? const Color(0xFF6C8C4C)
                                      : const Color(0xFFF0D9B5),
                                  fontSize: squareSize * 0.18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (row == 7)
                            Positioned(
                              right: 3,
                              bottom: 1,
                              child: Text(
                                String.fromCharCode(97 + column),
                                style: TextStyle(
                                  color: isLight
                                      ? const Color(0xFF6C8C4C)
                                      : const Color(0xFFF0D9B5),
                                  fontSize: squareSize * 0.18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ChessPiece extends StatelessWidget {
  const _ChessPiece({
    required this.piece,
    required this.size,
    this.shadow = false,
  });

  final chess.Piece piece;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return ClassicChessPieceIcon(
      pieceType: piece.type.name,
      isWhite: piece.color == chess.Color.WHITE,
      size: size,
      shadow: shadow,
    );
  }
}

class ClassicChessPieceIcon extends StatelessWidget {
  const ClassicChessPieceIcon({
    super.key,
    required this.pieceType,
    required this.isWhite,
    required this.size,
    this.shadow = false,
  });

  final String pieceType;
  final bool isWhite;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final symbol = _pieceSymbol(pieceType);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isWhite ? 2.0 : 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = isWhite ? const Color(0xFF202020) : const Color(0xFF000000);
    final fillColor = isWhite
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    return Semantics(
      label: '${isWhite ? 'White' : 'Black'} ${_pieceName(pieceType)}',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: size,
              height: 1,
              foreground: outline,
              shadows: shadow
                  ? const [
                      Shadow(
                        color: Color(0x77000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : const [
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 1.5,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
          ),
          ColorFiltered(
            // Some Android builds render individual chess characters with a
            // colored/gray fallback font. Force the complete glyph silhouette
            // to the side's single color so pawns and major pieces match.
            colorFilter: ColorFilter.mode(fillColor, BlendMode.srcIn),
            child: Text(
              symbol,
              style: TextStyle(fontSize: size, height: 1, color: fillColor),
            ),
          ),
        ],
      ),
    );
  }
}

String _pieceSymbol(String pieceType) {
  const symbols = {
    // FE0E requests monochrome text presentation instead of an emoji glyph.
    'k': '\u2654\uFE0E',
    'q': '\u2655\uFE0E',
    'r': '\u2656\uFE0E',
    'b': '\u2657\uFE0E',
    'n': '\u2658\uFE0E',
    'p': '\u2659\uFE0E',
  };
  return symbols[pieceType] ?? '';
}

String _pieceName(String pieceType) {
  return const {
        'k': 'king',
        'q': 'queen',
        'r': 'rook',
        'b': 'bishop',
        'n': 'knight',
        'p': 'pawn',
      }[pieceType] ??
      'piece';
}
