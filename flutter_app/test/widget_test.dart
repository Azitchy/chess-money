import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/dashboard_widgets.dart';
import 'package:flutter_app/src/registered_user.dart';
import 'package:flutter_app/src/screens/dashboard_screen.dart';
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
      MaterialApp(home: ProfileScreen(apiClient: apiClient, demoMode: true)),
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
