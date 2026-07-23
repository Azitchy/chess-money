import 'dart:math';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/dashboard_widgets.dart';
import 'package:flutter_app/src/bot_move_engine.dart';
import 'package:flutter_app/src/chess_puzzle.dart';
import 'package:flutter_app/src/interactive_chess_board.dart';
import 'package:flutter_app/src/live_match.dart';
import 'package:flutter_app/src/match_summary.dart';
import 'package:flutter_app/src/player_progress.dart';
import 'package:flutter_app/src/registered_user.dart';
import 'package:flutter_app/src/screens/dashboard_screen.dart';
import 'package:flutter_app/src/screens/login_screen.dart';
import 'package:flutter_app/src/screens/profile_screen.dart';
import 'package:flutter_app/src/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const onlinePlayer = RegisteredUser(
    id: 7,
    name: 'Maya Knight',
    username: 'maya_knight',
    email: 'maya@example.com',
    isOnline: true,
    lastSeenAt: null,
  );
  const offlinePlayer = RegisteredUser(
    id: 8,
    name: 'Leo Rook',
    username: 'leo_rook',
    email: 'leo@example.com',
    isOnline: false,
    lastSeenAt: null,
  );

  test('API decimal strings parse without a type-cast crash', () {
    final summary = MatchSummary.fromJson({
      'id': '42',
      'status': 'active',
      'mode': 'competitive',
      'bet_amount': '12.50',
      'winner_id': null,
    });
    final live = LiveMatch.fromJson({
      'id': '42',
      'player_1_id': '7',
      'status': 'active',
      'mode': 'competitive',
      'bet_amount': '12.50',
      'time_control': 'blitz',
      'moves': [
        {'from': 'e2', 'to': 'e4'},
      ],
    });
    final progress = PlayerProgress.fromJson({
      'id': '7',
      'rating': '1',
      'level': '1',
      'awarded': true,
    });

    expect(summary.betAmount, 12.5);
    expect(live.betAmount, 12.5);
    expect(live.moves.single.to, 'e4');
    expect(progress.rating, 1);
    expect(progress.level, 1);
    expect(progress.awarded, isTrue);
  });

  testWidgets('login hides backend, quick accounts, and demo access', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = await ApiClient.create();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(apiClient: apiClient, onLogin: () {}),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Backend URL'), findsNothing);
    expect(find.text('Save API address'), findsNothing);
    expect(find.text('Quick login accounts'), findsNothing);
    expect(find.text('Skip login for demo'), findsNothing);
  });

  testWidgets('chess pieces use responsive white and black PNG assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            ClassicChessPieceIcon(pieceType: 'k', isWhite: true, size: 48),
            ClassicChessPieceIcon(pieceType: 'k', isWhite: false, size: 48),
          ],
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    expect(
      (images[0].image as AssetImage).assetName,
      'lib/src/assets/white_king.png',
    );
    expect(
      (images[1].image as AssetImage).assetName,
      'lib/src/assets/black_king.png',
    );
    expect(images.every((image) => image.fit == BoxFit.contain), isTrue);
  });

  test('bot difficulty profiles increase search strength', () {
    expect(ChessBotEngine.profileFor('Beginner').searchDepth, 0);
    expect(ChessBotEngine.profileFor('Intermediate').searchDepth, 2);
    expect(ChessBotEngine.profileFor('Advanced').searchDepth, 3);
    expect(
      ChessBotEngine.profileFor('Beginner').candidatePool,
      greaterThan(ChessBotEngine.profileFor('Intermediate').candidatePool),
    );
    expect(ChessBotEngine.profileFor('Advanced').candidatePool, 1);
  });

  test('advanced bot finds a forced checkmate in one', () {
    final game = chess.Chess.fromFEN('8/8/8/8/8/5kq1/8/7K b - - 0 1');
    final engine = ChessBotEngine(random: Random(1));

    final move = engine.chooseMove(game, 'Advanced');
    game.move(move);

    expect(move.fromAlgebraic, 'g3');
    expect(move.toAlgebraic, 'g2');
    expect(game.in_checkmate, isTrue);
  });

  test('every puzzle solution line contains legal chess moves', () {
    for (final puzzle in chessPuzzles) {
      final game = chess.Chess.fromFEN(puzzle.fen);
      for (final uci in puzzle.solutionLine) {
        final moved = game.move({
          'from': uci.substring(0, 2),
          'to': uci.substring(2, 4),
          'promotion': 'q',
        });
        expect(moved, isTrue, reason: '${puzzle.id}: $uci must be legal');
      }
    }
  });

  test('daily puzzle is stable while random puzzles avoid repetition', () {
    final today = DateTime.utc(2026, 7, 15);
    expect(dailyPuzzleIndex(today), dailyPuzzleIndex(today));
    expect(
      dailyPuzzleIndex(today.add(const Duration(days: 1))),
      isNot(dailyPuzzleIndex(today)),
    );
    expect(randomPuzzleIndex(Random(2), excluding: 3), isNot(3));
    expect(dailyChessPuzzle(today).fen, dailyChessPuzzle(today).fen);
    expect(
      dailyChessPuzzle(today.add(const Duration(days: 1))).id,
      isNot(dailyChessPuzzle(today).id),
    );
  });

  test('procedural puzzle generator creates endless legal lessons', () {
    final positions = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      final puzzle = generateRandomChessLesson(Random(seed));
      positions.add(puzzle.fen);
      final uci = puzzle.solutionLine.first;
      final game = chess.Chess.fromFEN(puzzle.fen);
      expect(
        game.move({
          'from': uci.substring(0, 2),
          'to': uci.substring(2, 4),
          'promotion': 'q',
        }),
        isTrue,
        reason: 'Generated lesson $seed must contain a legal solution.',
      );
    }
    expect(positions.length, greaterThan(25));
  });

  testWidgets('online player tile shows avatar, status, and challenge action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTile(
            user: onlinePlayer,
            buttonLabel: 'Send challenge',
            onChallenge: () {},
          ),
        ),
      ),
    );

    expect(find.text('MK'), findsOneWidget);
    expect(find.text('Online now'), findsOneWidget);
    expect(find.text('Send challenge'), findsOneWidget);
  });

  testWidgets('offline player tile shows status and disables challenges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerTile(
            user: offlinePlayer,
            buttonLabel: 'Offline',
            onChallenge: null,
          ),
        ),
      ),
    );

    expect(find.text('Offline'), findsNWidgets(2));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('dashboard presence pill switches online and offline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = await ApiClient.create();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          apiClient: apiClient,
          demoMode: true,
          onLogout: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    var presenceSwitch = tester.widget<Switch>(
      find.byKey(const Key('presence-switch')),
    );
    expect(presenceSwitch.value, isTrue);

    await tester.tap(find.byKey(const Key('presence-switch')));
    await tester.pump();
    presenceSwitch = tester.widget<Switch>(
      find.byKey(const Key('presence-switch')),
    );
    expect(presenceSwitch.value, isFalse);
    expect(find.text('You are now offline'), findsOneWidget);
  });

  testWidgets('match center has no manual join bypass', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = await ApiClient.create();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          apiClient: apiClient,
          demoMode: true,
          onLogout: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();

    expect(find.text('Match Invitations'), findsOneWidget);
    expect(
      find.textContaining('Manual joining by Match ID is disabled'),
      findsOneWidget,
    );
    expect(find.widgetWithText(MiniActionButton, 'Join'), findsNothing);
  });

  testWidgets('home shows chess activities and opens puzzle practice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = await ApiClient.create();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          apiClient: apiClient,
          demoMode: true,
          onLogout: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('solve-puzzles-card')), findsOneWidget);
    expect(find.text('Rating 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('play-bots-card')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Level 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('solve-puzzles-card')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('solve-puzzles-card')));
    await tester.pumpAndSettle();

    expect(find.text('Find the strongest move for White.'), findsOneWidget);
    expect(find.byType(ChessActivityScreen), findsOneWidget);
  });

  testWidgets('puzzle board accepts the correct legal move', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChessActivityScreen(
          title: 'Solve Puzzles',
          subtitle: 'Find the strongest move.',
          activity: ChessActivity.puzzles,
          initialBoardVariant: 0,
          randomizePuzzles: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('square-d8')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('square-h4')));
    await tester.pump();

    expect(find.textContaining('Correct! Qh4 is checkmate'), findsOneWidget);
    expect(find.textContaining('Qh4#'), findsOneWidget);
    expect(find.byKey(const Key('puzzle-rating-toast')), findsOneWidget);
    expect(find.textContaining('Rating +1'), findsOneWidget);
    expect(find.text('Rating 1'), findsOneWidget);
  });

  testWidgets('multi-move puzzle plays a reply and asks for continuation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChessActivityScreen(
          title: 'Solve Puzzles',
          subtitle: 'Find the opening plan.',
          activity: ChessActivity.puzzles,
          initialBoardVariant: 6,
          randomizePuzzles: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('square-e2')));
    await tester.tap(find.byKey(const Key('square-e4')));
    await tester.pump();
    expect(find.text('Opponent is responding…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Opponent replied. Find the next best move.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('square-g1')));
    await tester.tap(find.byKey(const Key('square-f3')));
    await tester.pump();
    expect(
      find.textContaining('Correct! e4 claims the center'),
      findsOneWidget,
    );
  });

  testWidgets('daily puzzle shows its date and tomorrow unlock message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final solution = dailyChessPuzzle(now).solutionLine.first;

    await tester.pumpWidget(
      const MaterialApp(
        home: ChessActivityScreen(
          title: 'Daily Puzzle',
          subtitle: 'Today\'s challenge.',
          activity: ChessActivity.dailyPuzzle,
          initialBoardVariant: 0,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('${now.year}'), findsOneWidget);

    await tester.tap(find.byKey(Key('square-${solution.substring(0, 2)}')));
    await tester.tap(find.byKey(Key('square-${solution.substring(2, 4)}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('daily-puzzle-complete-toast')),
      findsOneWidget,
    );
    expect(
      find.textContaining('A new puzzle will unlock tomorrow'),
      findsOneWidget,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('daily_puzzle_completed_date'), isNotNull);
  });

  testWidgets('bot board makes a reply after the player moves', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChessActivityScreen(
          title: 'Play Bots',
          subtitle: 'Play a practice game.',
          activity: ChessActivity.bots,
          initialBoardVariant: 0,
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('interactive-chess-board'))).width,
      greaterThan(700),
    );

    await tester.tap(find.byKey(const Key('square-e2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('square-e4')));
    await tester.pump();
    expect(find.text('Beginner bot is thinking…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('White to move'), findsOneWidget);
    expect(find.textContaining('e4'), findsOneWidget);
  });

  testWidgets('player checkmate shows level-up toast and increments level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChessActivityScreen(
          title: 'Play Bots',
          subtitle: 'Play a practice game.',
          activity: ChessActivity.bots,
          initialBoardVariant: 0,
          initialFen:
              'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('square-h5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('square-f7')));
    await tester.pump();

    expect(find.byKey(const Key('level-up-toast')), findsOneWidget);
    expect(
      find.text('Bot defeated! Level +1. You are now Level 1.'),
      findsOneWidget,
    );
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Checkmate — White wins'), findsOneWidget);
  });

  testWidgets('completed bot game returns to home after the win toast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChessActivityScreen(
                      title: 'Play Bots',
                      subtitle: 'Play a practice game.',
                      activity: ChessActivity.bots,
                      initialBoardVariant: 0,
                      initialFen:
                          'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
                    ),
                  ),
                ),
                child: const Text('Home screen'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('square-h5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('square-f7')));
    await tester.pump();
    expect(find.byType(ChessActivityScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(ChessActivityScreen), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('challenge success screen prominently shows the new match ID', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChallengeSuccessScreen(
          matchId: 321,
          opponent: onlinePlayer,
          betAmount: 10,
          timeControl: 'blitz',
        ),
      ),
    );

    expect(find.text('Challenge sent!'), findsOneWidget);
    expect(find.byKey(const Key('challenge-match-id')), findsOneWidget);
    expect(find.text('#321'), findsOneWidget);
    expect(find.text('@maya_knight can now join your match.'), findsOneWidget);
    expect(find.text('Copy match ID'), findsOneWidget);
  });

  testWidgets('profile screen edits and saves all personal details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = await ApiClient.create();

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          apiClient: apiClient,
          demoMode: true,
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Contact number'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Address'), findsOneWidget);
    expect(find.byKey(const Key('pick-profile-avatar')), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Edited Player',
    );
    final saveButton = find.text('Save changes');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Demo profile updated on this screen'), findsOneWidget);
  });
}
