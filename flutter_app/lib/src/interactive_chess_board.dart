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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF34422B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x55FFFFFF),
            blurRadius: 2,
            offset: Offset(-1, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
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
                final isLastMove =
                    lastMoveFrom == square || lastMoveTo == square;
                final isLegalTarget = legalTargets.contains(square);
                final canDrag = enabled && piece?.color == game.turn;

                return DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    return legalTargets.contains(square) &&
                        details.data == selectedSquare;
                  },
                  onAcceptWithDetails: (details) =>
                      onMove(details.data, square),
                  builder: (context, candidates, rejected) {
                    final squareColors = isSelected
                        ? const [Color(0xFFFFE990), Color(0xFFE5AD32)]
                        : isLastMove
                        ? const [Color(0xFFE8F58C), Color(0xFFADC83E)]
                        : isLight
                        ? const [Color(0xFFFFF0D1), Color(0xFFD8BA7D)]
                        : const [Color(0xFF98BC6B), Color(0xFF587E3D)];

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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: squareColors,
                          ),
                          border: Border.all(
                            color: isLight
                                ? const Color(0x22936F38)
                                : const Color(0x22304425),
                            width: 0.45,
                          ),
                        ),
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
    final assetPath = _pieceAssetPath(pieceType, isWhite: isWhite);
    final needsWhiteFinish = isWhite && (pieceType == 'n' || pieceType == 'p');

    Widget image = Image.asset(
      assetPath,
      key: ValueKey('piece-asset-${isWhite ? 'white' : 'black'}-$pieceType'),
      width: size,
      height: size * 0.96,
      alignment: Alignment.bottomCenter,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Text(
        _pieceSymbol(pieceType),
        style: TextStyle(
          fontSize: size * 0.86,
          height: 1,
          color: isWhite ? Colors.white : Colors.black,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
    );

    // The supplied white knight and pawn artwork contains the dark material.
    // Retain its 3D light/shadow detail while giving it the white-side finish.
    if (needsWhiteFinish) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.0,
          0,
          0,
          0,
          145,
          0,
          0.82,
          0,
          0,
          116,
          0,
          0,
          0.36,
          0,
          52,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    }

    return Semantics(
      label: '${isWhite ? 'White' : 'Black'} ${_pieceName(pieceType)}',
      child: SizedBox.square(
        dimension: size,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(shadow ? 1.52 : 1.42, 1, 1),
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.015, bottom: size * 0.025),
            child: image,
          ),
        ),
      ),
    );
  }
}

String _pieceAssetPath(String pieceType, {required bool isWhite}) {
  const names = {
    'k': 'king',
    'q': 'queen',
    'r': 'rook',
    'b': 'bishop',
    'n': 'knight',
    'p': 'pawn',
  };
  final side = isWhite ? 'white' : 'black';
  return 'lib/src/assets/${side}_${names[pieceType] ?? 'pawn'}.png';
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
