import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../bot_move_engine.dart';
import '../dashboard_widgets.dart';
import '../interactive_chess_board.dart';
import '../live_match.dart';
import '../match_summary.dart';
import '../registered_user.dart';
import '../services/api_client.dart';
import 'profile_screen.dart';
import 'network_chess_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiClient,
    required this.onLogout,
    this.demoMode = false,
  });

  final ApiClient apiClient;
  final VoidCallback onLogout;
  final bool demoMode;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageTitles = [
    'Home',
    'Online Players',
    'Wallet Funding',
    'Match Center',
    'Recent Matches',
  ];

  bool _loading = true;
  bool _isOnline = true;
  bool _updatingPresence = false;
  Timer? _presenceHeartbeat;
  Timer? _challengePoller;
  bool _pollingMatches = false;
  int? _currentUserId;
  int _rating = 0;
  int _level = 0;
  List<LiveMatch> _challenges = const [];
  final Set<int> _announcedChallenges = {};
  final Set<int> _openedMatches = {};
  int _selectedIndex = 0;
  String? _error;
  double _balance = 0;
  List<MatchSummary> _history = const [];
  List<RegisteredUser> _users = const [];

  final _fundAmount = TextEditingController();
  final _fundNote = TextEditingController();
  final _playerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _playerSearch.addListener(_handleSearchChanged);
    if (widget.demoMode) {
      _loadDemoData();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _presenceHeartbeat?.cancel();
    _challengePoller?.cancel();
    _playerSearch.removeListener(_handleSearchChanged);
    _fundAmount.dispose();
    _fundNote.dispose();
    _playerSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.demoMode
              ? '${_pageTitles[_selectedIndex]} (Demo)'
              : _pageTitles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        actions: [
          _PresencePill(
            isOnline: _isOnline,
            isUpdating: _updatingPresence,
            onChanged: _updatePresence,
          ),
          if (!widget.demoMode)
            Badge(
              isLabelVisible: _challenges.isNotEmpty,
              label: Text('${_challenges.length}'),
              child: IconButton(
                tooltip: 'Match challenges',
                onPressed: _showChallengeInbox,
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.deepPurple,
              ),
            ),
          IconButton(
            tooltip: 'My profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(
                    apiClient: widget.apiClient,
                    demoMode: widget.demoMode,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
            color: AppColors.deepPurple,
          ),
          IconButton(
            onPressed: () async {
              if (!widget.demoMode) {
                await widget.apiClient.logout();
              }
              widget.onLogout();
            },
            icon: const Icon(Icons.logout_rounded),
            color: AppColors.deepPurple,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomePage(),
                _buildPlayersPage(),
                _buildWalletPage(),
                _buildMatchActionsPage(),
                _buildRecentMatchesPage(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Players',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_merge_outlined),
            selectedIcon: Icon(Icons.call_merge_rounded),
            label: 'Match',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Recent',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(String pageKey, List<Widget> children) {
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: widget.demoMode ? () async {} : _load,
      child: ListView(
        key: PageStorageKey<String>(pageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          if (widget.demoMode) ...[
            const DemoBanner(),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    final onlinePlayers = _filteredOnlinePlayers;
    final dailyBoardVariant = DateTime.now()
        .toUtc()
        .difference(DateTime.utc(2026))
        .inDays
        .abs()
        .remainder(4);

    return _buildPage('home', [
      _ChessHomeHeader(
        balance: _balance,
        matches: _history.length,
        onlinePlayers: onlinePlayers.length,
      ),
      const SizedBox(height: 24),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'What do you want to play?',
          style: TextStyle(
            color: AppColors.heading,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 14),
      _ChessActivityCard(
        key: const Key('solve-puzzles-card'),
        title: 'Solve Puzzles',
        subtitle: 'Find the right move!',
        accent: const Color(0xFFF56A2D),
        icon: Icons.extension_rounded,
        boardVariant: 0,
        badge: 'Rating $_rating',
        onTap: () => _openChessActivity(
          title: 'Solve Puzzles',
          subtitle: 'Find the strongest move for White.',
          activity: ChessActivity.puzzles,
          boardVariant: 0,
        ),
      ),
      const SizedBox(height: 12),
      _ChessActivityCard(
        key: const Key('daily-puzzle-card'),
        title: 'Daily Puzzle',
        subtitle: 'A fresh challenge every day',
        accent: const Color(0xFF63A83B),
        icon: Icons.calendar_month_rounded,
        boardVariant: dailyBoardVariant,
        badge: 'Today',
        onTap: () => _openChessActivity(
          title: 'Daily Puzzle',
          subtitle: 'Solve today\'s featured position.',
          activity: ChessActivity.dailyPuzzle,
          boardVariant: dailyBoardVariant,
        ),
      ),
      const SizedBox(height: 12),
      _ChessActivityCard(
        key: const Key('play-bots-card'),
        title: 'Play Bots',
        subtitle: 'Practice at your own pace',
        accent: const Color(0xFF5B7BD5),
        icon: Icons.smart_toy_rounded,
        boardVariant: 2,
        badge: 'Level $_level',
        onTap: () => _openChessActivity(
          title: 'Play Bots',
          subtitle: 'Choose a bot and sharpen your game.',
          activity: ChessActivity.bots,
          boardVariant: 2,
        ),
      ),
      const SizedBox(height: 12),
      _ChessActivityCard(
        key: const Key('play-opponents-card'),
        title: 'Play with Opponents',
        subtitle: onlinePlayers.isEmpty
            ? 'Players will appear when online'
            : '${onlinePlayers.length} online now',
        accent: AppColors.deepPurple,
        icon: Icons.groups_rounded,
        boardVariant: 3,
        badge: 'Live',
        onTap: () => setState(() => _selectedIndex = 1),
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 58,
        child: FilledButton.icon(
          key: const Key('play-opponents-button'),
          onPressed: () => setState(() => _selectedIndex = 1),
          icon: const Icon(Icons.sports_esports_rounded),
          label: const Text(
            'Play with an opponent',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF63A83B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ]);
  }

  void _openChessActivity({
    required String title,
    required String subtitle,
    required ChessActivity activity,
    required int boardVariant,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChessActivityScreen(
          title: title,
          subtitle: subtitle,
          activity: activity,
          initialBoardVariant: boardVariant,
        ),
      ),
    );
  }

  Widget _buildPlayersPage() {
    final players = _filteredPlayers;
    final onlinePlayers = players.where((user) => user.isOnline).toList();
    final offlinePlayers = players.where((user) => !user.isOnline).toList();

    return _buildPage('players', [
      SectionCard(
        title: 'Players',
        icon: Icons.people_alt_outlined,
        child: Column(
          children: [
            DashboardInputField(
              controller: _playerSearch,
              label: 'Search players',
            ),
            const SizedBox(height: 12),
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No players found.'),
              )
            else ...[
              _PlayerSectionLabel(
                label: 'Online now',
                count: onlinePlayers.length,
                color: const Color(0xFF16794C),
              ),
              ...onlinePlayers.map(
                (user) => PlayerTile(
                  user: user,
                  buttonLabel: 'Send challenge',
                  onChallenge: widget.demoMode
                      ? _demoAction
                      : () => _showChallengeDialog(user),
                ),
              ),
              if (offlinePlayers.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PlayerSectionLabel(
                  label: 'Offline',
                  count: offlinePlayers.length,
                  color: AppColors.mutedText,
                ),
                ...offlinePlayers.map(
                  (user) => PlayerTile(
                    user: user,
                    buttonLabel: 'Offline',
                    onChallenge: null,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _buildWalletPage() {
    return _buildPage('wallet', [
      SectionCard(
        title: 'Request Wallet Funding',
        icon: Icons.account_balance_wallet_outlined,
        child: Column(
          children: [
            DashboardInputField(
              controller: _fundAmount,
              label: 'Amount',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DashboardInputField(
              controller: _fundNote,
              label: 'Note (optional)',
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: 'Send Request',
              onPressed: widget.demoMode ? _demoAction : _requestFunds,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildMatchActionsPage() {
    return _buildPage('match-actions', [
      SectionCard(
        title: 'Match Invitations',
        icon: Icons.notifications_active_outlined,
        child: Column(
          children: [
            const Text(
              'A chess match starts only after the challenged player accepts its notification. Manual joining by Match ID is disabled.',
              style: TextStyle(color: AppColors.mutedText, height: 1.45),
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: _challenges.isEmpty
                  ? 'Check notifications'
                  : 'View ${_challenges.length} challenge${_challenges.length == 1 ? '' : 's'}',
              onPressed: widget.demoMode ? _demoAction : _showChallengeInbox,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildRecentMatchesPage() {
    return _buildPage('recent-matches', [
      SectionCard(
        title: 'Recent Matches',
        icon: Icons.history_rounded,
        child: Column(
          children: _history.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No matches yet.'),
                  ),
                ]
              : _history.map((item) => MatchTile(match: item)).toList(),
        ),
      ),
    ]);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final balance = await widget.apiClient.getWalletBalance();
      final progress = await widget.apiClient.getPlayerProgress();
      final history = await widget.apiClient.getMatchHistory();
      final users = await widget.apiClient.getUsers();
      final isOnline = await widget.apiClient.getPresence();
      setState(() {
        _balance = balance;
        _currentUserId = progress.userId;
        _rating = progress.rating;
        _level = progress.level;
        _history = history
            .whereType<Map<String, dynamic>>()
            .map(MatchSummary.fromJson)
            .toList(growable: false);
        _users = users;
        _isOnline = isOnline;
      });
      _syncPresenceHeartbeat();
      _syncChallengePolling();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDemoData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) {
      return;
    }

    setState(() {
      _balance = 128.50;
      _rating = 0;
      _level = 0;
      _history = const [
        MatchSummary(
          id: 101,
          status: 'completed',
          mode: 'casual',
          betAmount: 0,
          winnerId: null,
        ),
        MatchSummary(
          id: 102,
          status: 'active',
          mode: 'competitive',
          betAmount: 25,
          winnerId: null,
        ),
      ];
      _users = [
        RegisteredUser(
          id: 201,
          name: 'Maya Knight',
          username: 'maya_knight',
          email: 'maya@example.com',
          isOnline: true,
          lastSeenAt: DateTime.now(),
        ),
        RegisteredUser(
          id: 202,
          name: 'Leo Rook',
          username: 'leo_rook',
          email: 'leo@example.com',
          isOnline: true,
          lastSeenAt: DateTime.now().subtract(const Duration(seconds: 20)),
        ),
        RegisteredUser(
          id: 203,
          name: 'Aria Bishop',
          username: 'aria_bishop',
          email: 'aria@example.com',
          isOnline: false,
          lastSeenAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ];
      _loading = false;
    });
  }

  Future<void> _requestFunds() async {
    try {
      final amount = double.parse(_fundAmount.text.trim());
      final note = _fundNote.text.trim();
      await widget.apiClient.requestFunds(
        amount,
        note: note.isEmpty ? null : note,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Funding request sent')));
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    }
  }

  void _demoAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo mode: API action disabled.')),
    );
  }

  Future<void> _showChallengeDialog(RegisteredUser user) async {
    final betController = TextEditingController(text: '10');
    String timeControl = 'blitz';

    try {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Challenge @${user.username}'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: betController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Bet amount',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: timeControl,
                        decoration: const InputDecoration(
                          labelText: 'Time control',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'bullet',
                            child: Text('Bullet'),
                          ),
                          DropdownMenuItem(
                            value: 'blitz',
                            child: Text('Blitz'),
                          ),
                          DropdownMenuItem(
                            value: 'rapid',
                            child: Text('Rapid'),
                          ),
                          DropdownMenuItem(
                            value: 'classical',
                            child: Text('Classical'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            timeControl = value ?? 'blitz';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The challenge will be created as a competitive match and can be joined by the selected player.',
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      if (shouldCreate != true) {
        return;
      }

      final betAmount = double.parse(betController.text.trim());
      final created = await widget.apiClient.createMatch(
        mode: 'competitive',
        betAmount: betAmount,
        timeControl: timeControl,
        opponentId: user.id,
      );

      if (!mounted) {
        return;
      }

      final matchId = int.tryParse(created['id']?.toString() ?? '') ?? 0;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChallengeSuccessScreen(
            matchId: matchId,
            opponent: user,
            betAmount: betAmount,
            timeControl: timeControl,
          ),
        ),
      );

      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      betController.dispose();
    }
  }

  void _syncChallengePolling() {
    _challengePoller?.cancel();
    if (widget.demoMode || !_isOnline) return;
    _challengePoller = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollMatches(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollMatches());
  }

  Future<void> _pollMatches() async {
    if (_pollingMatches || !mounted || widget.demoMode) return;
    _pollingMatches = true;
    try {
      final challenges = await widget.apiClient.getChallenges();
      final activeMatches = await widget.apiClient.getActiveMatches();
      if (!mounted) return;
      setState(() => _challenges = challenges);

      final newChallenge = challenges
          .where((match) => !_announcedChallenges.contains(match.id))
          .firstOrNull;
      if (newChallenge != null) {
        _announcedChallenges.add(newChallenge.id);
        await _showIncomingChallenge(newChallenge);
      }

      final accepted = activeMatches
          .where((match) => !_openedMatches.contains(match.id))
          .firstOrNull;
      if (accepted != null && mounted) {
        _openedMatches.add(accepted.id);
        await _openNetworkMatch(accepted);
      }
    } catch (_) {
      // Keep dashboard polling unobtrusive; manual refresh still reports errors.
    } finally {
      _pollingMatches = false;
    }
  }

  Future<void> _showChallengeInbox() async {
    await _pollMatches();
    if (!mounted) return;
    if (_challenges.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pending challenges.')));
      return;
    }
    await _showIncomingChallenge(_challenges.first);
  }

  Future<void> _showIncomingChallenge(LiveMatch match) async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.sports_esports_rounded,
          size: 42,
          color: AppColors.deepPurple,
        ),
        title: const Text('New chess challenge'),
        content: Text(
          '${match.playerOne?.name ?? 'A player'} challenged you.\n\n'
          'Stake: ${match.betAmount.toStringAsFixed(2)}\n'
          'Time: ${_titleCase(match.timeControl)}\n\n'
          'On acceptance, the stake is locked from both wallets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'reject'),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'accept'),
            child: const Text('Accept & play'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'reject') {
        await widget.apiClient.rejectChallenge(match.id);
        if (mounted) {
          setState(
            () => _challenges = _challenges
                .where((item) => item.id != match.id)
                .toList(),
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Challenge rejected')));
        }
        return;
      }
      final active = await widget.apiClient.acceptChallenge(match.id);
      _openedMatches.add(active.id);
      if (mounted) {
        setState(
          () => _challenges = _challenges
              .where((item) => item.id != match.id)
              .toList(),
        );
        await _openNetworkMatch(active);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) await _pollMatches();
    }
  }

  Future<void> _openNetworkMatch(LiveMatch match) async {
    final userId = _currentUserId;
    if (!mounted || userId == null) return;
    if (match.status != 'active' || match.acceptedAt == null) {
      setState(() => _error = 'Waiting for the challenged player to accept.');
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NetworkChessScreen(
          apiClient: widget.apiClient,
          match: match,
          currentUserId: userId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  List<RegisteredUser> get _onlinePlayers {
    final players = _users.where((user) => user.isOnline).toList();
    players.sort((a, b) {
      final aSeen = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSeen = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSeen.compareTo(aSeen);
    });
    return players;
  }

  List<RegisteredUser> get _filteredOnlinePlayers {
    final query = _playerSearch.text.trim().toLowerCase();
    final players = _onlinePlayers;
    if (query.isEmpty) {
      return players;
    }

    return players
        .where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.username.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<RegisteredUser> get _filteredPlayers {
    final query = _playerSearch.text.trim().toLowerCase();
    final players = List<RegisteredUser>.from(_users)
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        final aSeen = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bSeen = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bSeen.compareTo(aSeen);
      });
    if (query.isEmpty) return players;

    return players
        .where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.username.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _updatePresence(bool isOnline) async {
    if (_updatingPresence) return;
    setState(() => _updatingPresence = true);

    try {
      final updated = widget.demoMode
          ? isOnline
          : await widget.apiClient.updatePresence(isOnline);
      if (!mounted) return;
      setState(() {
        _isOnline = updated;
        _error = null;
      });
      _syncPresenceHeartbeat();
      _syncChallengePolling();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated ? 'You are now online' : 'You are now offline'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _updatingPresence = false);
    }
  }

  void _syncPresenceHeartbeat() {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    if (widget.demoMode) return;

    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        if (_isOnline) {
          await widget.apiClient.updatePresence(true);
        }
        final users = await widget.apiClient.getUsers();
        if (mounted) {
          setState(() => _users = users);
        }
      } catch (_) {
        // The next successful refresh restores the latest presence information.
      }
    });
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

enum ChessActivity { puzzles, dailyPuzzle, bots }

class ChessActivityScreen extends StatefulWidget {
  const ChessActivityScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activity,
    required this.initialBoardVariant,
    this.initialFen,
  });

  final String title;
  final String subtitle;
  final ChessActivity activity;
  final int initialBoardVariant;
  final String? initialFen;

  @override
  State<ChessActivityScreen> createState() => _ChessActivityScreenState();
}

class _ChessActivityScreenState extends State<ChessActivityScreen> {
  late chess.Chess _game;
  late int _puzzleIndex;
  String _botLevel = 'Beginner';
  String? _selectedSquare;
  Set<String> _legalTargets = const {};
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _notice;
  bool _puzzleSolved = false;
  bool _botThinking = false;
  Timer? _homeRedirectTimer;
  final ChessBotEngine _botEngine = ChessBotEngine();

  bool get _isBot => widget.activity == ChessActivity.bots;
  _PuzzleData get _puzzle => _puzzles[_puzzleIndex % _puzzles.length];

  @override
  void initState() {
    super.initState();
    _puzzleIndex = widget.initialBoardVariant % _puzzles.length;
    _resetGame(notify: false);
  }

  @override
  void dispose() {
    _homeRedirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Text(
            widget.subtitle,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 16),
          ),
          const SizedBox(height: 18),
          if (_isBot) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_botLevel),
              initialValue: _botLevel,
              decoration: InputDecoration(
                labelText: 'Bot difficulty',
                prefixIcon: const Icon(Icons.smart_toy_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                DropdownMenuItem(
                  value: 'Intermediate',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
              ],
              onChanged: (value) {
                setState(() => _botLevel = value ?? 'Beginner');
                _resetGame();
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ChessBotEngine.profileFor(_botLevel).description,
                key: const Key('bot-difficulty-description'),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _GameStatusBar(
            message: _statusMessage,
            isPositive: _puzzleSolved || _game.in_checkmate,
            isThinking: _botThinking,
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AspectRatio(
                aspectRatio: 1,
                child: InteractiveChessBoard(
                  game: _game,
                  selectedSquare: _selectedSquare,
                  legalTargets: _legalTargets,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  enabled: !_botThinking && !_puzzleSolved && !_game.game_over,
                  onSquareTap: _handleSquareTap,
                  onMove: _tryMove,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BoardControl(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed: _game.getHistory().isEmpty || _botThinking
                      ? null
                      : _undo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BoardControl(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Hint',
                  onPressed: _isBot ? null : _showHint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BoardControl(
                  icon: Icons.refresh_rounded,
                  label: _puzzleSolved ? 'Next' : 'Reset',
                  onPressed: _puzzleSolved ? _nextPuzzle : _resetGame,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MoveHistory(moves: _game.getHistory().whereType<String>().toList()),
        ],
      ),
    );
  }

  String get _statusMessage {
    if (_notice != null) return _notice!;
    if (_game.in_checkmate) {
      return _game.turn == chess.Color.WHITE
          ? 'Checkmate — Black wins'
          : 'Checkmate — White wins';
    }
    if (_game.in_draw) return 'Draw';
    if (_botThinking) return '$_botLevel bot is thinking…';
    final side = _game.turn == chess.Color.WHITE ? 'White' : 'Black';
    return _game.in_check ? '$side is in check' : '$side to move';
  }

  void _handleSquareTap(String square) {
    if (_botThinking || _puzzleSolved || _game.game_over) return;
    if (_isBot && _game.turn == chess.Color.BLACK) return;

    final piece = _game.get(square);
    if (_selectedSquare != null && _legalTargets.contains(square)) {
      _tryMove(_selectedSquare!, square);
      return;
    }

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
      _notice = null;
    });
  }

  void _tryMove(String from, String to) {
    if (_isBot && _game.turn == chess.Color.BLACK) return;
    final uci = '$from$to';
    final moved = _game.move({'from': from, 'to': to, 'promotion': 'q'});
    if (!moved) return;

    if (!_isBot && uci != _puzzle.solution) {
      _game.undo();
      setState(() {
        _selectedSquare = null;
        _legalTargets = const {};
        _notice = 'That move is legal, but it is not the best move. Try again.';
      });
      return;
    }

    setState(() {
      _selectedSquare = null;
      _legalTargets = const {};
      _lastMoveFrom = from;
      _lastMoveTo = to;
      _notice = _isBot ? null : 'Correct! ${_puzzle.explanation}';
      _puzzleSolved = !_isBot;
    });

    if (_isBot && _game.in_checkmate && _game.turn == chess.Color.BLACK) {
      _handlePlayerWin();
    } else if (_isBot && !_game.game_over) {
      _playBotMove();
    }
  }

  Future<void> _playBotMove() async {
    setState(() => _botThinking = true);
    final thinkingTime = switch (_botLevel) {
      'Advanced' => const Duration(milliseconds: 650),
      'Intermediate' => const Duration(milliseconds: 450),
      _ => const Duration(milliseconds: 250),
    };
    await Future<void>.delayed(thinkingTime);
    if (!mounted) return;
    if (_game.game_over) {
      setState(() => _botThinking = false);
      return;
    }

    final moves = _game.moves({'asObjects': true}).cast<chess.Move>();
    if (moves.isEmpty) {
      setState(() => _botThinking = false);
      return;
    }
    final chosen = _botEngine.chooseMove(_game, _botLevel);
    final from = chosen.fromAlgebraic;
    final to = chosen.toAlgebraic;
    _game.move(chosen);
    if (!mounted) return;
    setState(() {
      _lastMoveFrom = from;
      _lastMoveTo = to;
      _botThinking = false;
    });
  }

  void _undo() {
    if (_isBot) _game.undo();
    _game.undo();
    setState(() {
      _selectedSquare = null;
      _legalTargets = const {};
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _notice = null;
      _puzzleSolved = false;
    });
  }

  void _showHint() {
    setState(() => _notice = _puzzle.hint);
  }

  void _nextPuzzle() {
    _puzzleIndex = (_puzzleIndex + 1) % _puzzles.length;
    _resetGame();
  }

  void _resetGame({bool notify = true}) {
    _game = _isBot
        ? widget.initialFen == null
              ? chess.Chess()
              : chess.Chess.fromFEN(widget.initialFen!)
        : chess.Chess.fromFEN(_puzzle.fen);
    _selectedSquare = null;
    _legalTargets = const {};
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _notice = null;
    _puzzleSolved = false;
    _botThinking = false;
    if (notify && mounted) setState(() {});
  }

  void _handlePlayerWin() {
    final upgradedLevel = switch (_botLevel) {
      'Beginner' => 'Intermediate',
      'Intermediate' => 'Advanced',
      _ => 'Advanced',
    };
    setState(() => _botLevel = upgradedLevel);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('level-up-toast'),
        content: const Text(
          'Congratulation your level is upgrade. Thank you!',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16794C),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    _homeRedirectTimer?.cancel();
    _homeRedirectTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}

class _PuzzleData {
  const _PuzzleData({
    required this.fen,
    required this.solution,
    required this.hint,
    required this.explanation,
  });

  final String fen;
  final String solution;
  final String hint;
  final String explanation;
}

const _puzzles = [
  _PuzzleData(
    fen: 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
    solution: 'd8h4',
    hint: 'Look for a queen check along the dark diagonal.',
    explanation: 'Qh4 is checkmate.',
  ),
  _PuzzleData(
    fen: 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
    solution: 'h5f7',
    hint: 'The f7 pawn is defended only by the king.',
    explanation: 'Qxf7 is checkmate.',
  ),
];

class _GameStatusBar extends StatelessWidget {
  const _GameStatusBar({
    required this.message,
    required this.isPositive,
    required this.isThinking,
  });

  final String message;
  final bool isPositive;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFE8FFF2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive ? const Color(0xFFB7E6C8) : const Color(0xFFDDE9FF),
        ),
      ),
      child: Row(
        children: [
          if (isThinking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isPositive ? Icons.check_circle_rounded : Icons.circle,
              color: isPositive
                  ? const Color(0xFF16794C)
                  : const Color(0xFF63A83B),
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              key: const Key('game-status'),
              style: const TextStyle(
                color: AppColors.heading,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardControl extends StatelessWidget {
  const _BoardControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      ),
    );
  }
}

class _MoveHistory extends StatelessWidget {
  const _MoveHistory({required this.moves});

  final List<String> moves;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moves',
            style: TextStyle(
              color: AppColors.heading,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            moves.isEmpty ? 'No moves yet' : moves.join('  '),
            key: const Key('move-history'),
            style: const TextStyle(color: AppColors.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ChessHomeHeader extends StatelessWidget {
  const _ChessHomeHeader({
    required this.balance,
    required this.matches,
    required this.onlinePlayers,
  });

  final double balance;
  final int matches;
  final int onlinePlayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252321),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF46423D),
                child: Text('♔', style: TextStyle(fontSize: 28)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for your next move?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Train, play, and improve every day.',
                      style: TextStyle(color: Color(0xFFBBB7B1)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC857)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HomeStat(
                label: 'Balance',
                value: '\$${balance.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              _HomeStat(label: 'Matches', value: '$matches'),
              const SizedBox(width: 8),
              _HomeStat(label: 'Online', value: '$onlinePlayers'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF35322F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFAAA6A0), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChessActivityCard extends StatelessWidget {
  const _ChessActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.boardVariant,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final int boardVariant;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDDE9FF)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: _ChessBoard(variant: boardVariant, compact: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: accent, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mutedText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChessBoard extends StatelessWidget {
  const _ChessBoard({required this.variant, this.compact = false});

  final int variant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pieces = _boardPieces[variant % _boardPieces.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (context, index) {
              final row = index ~/ 8;
              final column = index % 8;
              final isLight = (row + column).isEven;
              final piece = pieces[index];
              return Container(
                alignment: Alignment.center,
                color: isLight
                    ? const Color(0xFFF0D9B5)
                    : const Color(0xFF7FA35A),
                child: piece == null
                    ? null
                    : ClassicChessPieceIcon(
                        pieceType: _miniPieceType(piece),
                        isWhite: _whiteMiniPieces.contains(piece),
                        size: squareSize * 0.82,
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

const _whiteMiniPieces = {
  '\u2654',
  '\u2655',
  '\u2656',
  '\u2657',
  '\u2658',
  '\u2659',
};

String _miniPieceType(String symbol) {
  return switch (symbol) {
    '\u2654' || '\u265A' => 'k',
    '\u2655' || '\u265B' => 'q',
    '\u2656' || '\u265C' => 'r',
    '\u2657' || '\u265D' => 'b',
    '\u2658' || '\u265E' => 'n',
    _ => 'p',
  };
}

const _boardPieces = <Map<int, String>>[
  {
    5: '♚',
    11: '♟',
    14: '♟',
    17: '♛',
    19: '♟',
    23: '♜',
    26: '♙',
    28: '♗',
    35: '♘',
    46: '♙',
    49: '♖',
    61: '♔',
  },
  {
    1: '♚',
    4: '♜',
    9: '♟',
    10: '♟',
    18: '♛',
    22: '♟',
    27: '♙',
    31: '♙',
    36: '♕',
    41: '♖',
    54: '♙',
    58: '♘',
    62: '♔',
  },
  {
    0: '♜',
    1: '♞',
    2: '♝',
    3: '♛',
    4: '♚',
    5: '♝',
    6: '♞',
    7: '♜',
    8: '♟',
    9: '♟',
    10: '♟',
    11: '♟',
    12: '♟',
    13: '♟',
    14: '♟',
    15: '♟',
    48: '♙',
    49: '♙',
    50: '♙',
    51: '♙',
    52: '♙',
    53: '♙',
    54: '♙',
    55: '♙',
    56: '♖',
    57: '♘',
    58: '♗',
    59: '♕',
    60: '♔',
    61: '♗',
    62: '♘',
    63: '♖',
  },
  {
    2: '♜',
    4: '♚',
    6: '♜',
    8: '♟',
    9: '♟',
    13: '♟',
    14: '♟',
    18: '♞',
    20: '♟',
    27: '♙',
    34: '♗',
    36: '♙',
    45: '♘',
    48: '♙',
    49: '♙',
    53: '♙',
    54: '♙',
    58: '♖',
    60: '♔',
    63: '♖',
  },
];

class _PresencePill extends StatelessWidget {
  const _PresencePill({
    required this.isOnline,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool isOnline;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Semantics(
        label: 'Availability: ${isOnline ? 'Online' : 'Offline'}',
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 2),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFFE8FFF2) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isOnline
                  ? const Color(0xFFB7E6C8)
                  : const Color(0xFFD9E1EA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF94A3B8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isOnline
                      ? const Color(0xFF16794C)
                      : const Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isUpdating)
                const Padding(
                  padding: EdgeInsets.all(9),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                SizedBox(
                  height: 34,
                  child: Switch(
                    key: const Key('presence-switch'),
                    value: isOnline,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSectionLabel extends StatelessWidget {
  const _PlayerSectionLabel({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChallengeSuccessScreen extends StatelessWidget {
  const ChallengeSuccessScreen({
    super.key,
    required this.matchId,
    required this.opponent,
    required this.betAmount,
    required this.timeControl,
  });

  final int matchId;
  final RegisteredUser opponent;
  final double betAmount;
  final String timeControl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8FFF2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF16794C),
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Challenge sent!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.heading,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@${opponent.username} can now join your match.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDDE9FF)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'NEW MATCH ID',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '#$matchId',
                          key: const Key('challenge-match-id'),
                          style: const TextStyle(
                            color: AppColors.deepPurple,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: matchId.toString()),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Match ID copied'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy match ID'),
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: _ChallengeDetail(
                                label: 'Opponent',
                                value: opponent.name,
                              ),
                            ),
                            Expanded(
                              child: _ChallengeDetail(
                                label: 'Time',
                                value: _titleCase(timeControl),
                              ),
                            ),
                            Expanded(
                              child: _ChallengeDetail(
                                label: 'Stake',
                                value: '\$${betAmount.toStringAsFixed(2)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: 'Back to online players',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeDetail extends StatelessWidget {
  const _ChallengeDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
