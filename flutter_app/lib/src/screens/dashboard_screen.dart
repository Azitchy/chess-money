import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../app_colors.dart';
import '../bot_move_engine.dart';
import '../chess_puzzle.dart';
import '../dashboard_widgets.dart';
import '../interactive_chess_board.dart';
import '../live_match.dart';
import '../match_summary.dart';
import '../platform_notification.dart';
import '../player_progress.dart';
import '../registered_user.dart';
import '../services/api_client.dart';
import 'profile_screen.dart';
import 'network_chess_screen.dart';
import 'wallet_messages_screen.dart';

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
    'Load Balance',
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
  List<PlatformNotificationItem> _platformNotifications = const [];
  final Set<int> _announcedChallenges = {};
  final Set<int> _openedMatches = {};
  int _selectedIndex = 0;
  String? _homeError;
  String? _playersError;
  String? _walletError;
  String? _matchError;
  String? _recentMatchesError;
  double _balance = 0;
  List<MatchSummary> _history = const [];
  List<RegisteredUser> _users = const [];
  int _notificationUnreadCount = 0;
  WebSocketChannel? _notificationChannel;
  StreamSubscription? _notificationSubscription;
  Timer? _notificationReconnectTimer;
  bool _notificationSocketConnecting = false;
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
    _notificationReconnectTimer?.cancel();
    _notificationSubscription?.cancel();
    _notificationChannel?.sink.close();
    _playerSearch.removeListener(_handleSearchChanged);
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
          if (!widget.demoMode)
            Badge(
              isLabelVisible: _notificationUnreadCount > 0,
              label: Text('$_notificationUnreadCount'),
              child: IconButton(
                tooltip: 'Admin notifications',
                onPressed: _showPlatformNotifications,
                icon: const Icon(Icons.campaign_outlined),
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
                    onLogout: widget.onLogout,
                    demoMode: widget.demoMode,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
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

  Widget _buildPage(String pageKey, List<Widget> children, {String? error}) {
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: widget.demoMode ? () async {} : _load,
      child: ListView(
        key: PageStorageKey<String>(pageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (error != null) ...[
            ErrorBanner(message: error),
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
    ], error: _homeError);
  }

  Future<void> _openChessActivity({
    required String title,
    required String subtitle,
    required ChessActivity activity,
    required int boardVariant,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChessActivityScreen(
          title: title,
          subtitle: subtitle,
          activity: activity,
          initialBoardVariant: boardVariant,
          apiClient: widget.demoMode ? null : widget.apiClient,
          initialRating: _rating,
          initialLevel: _level,
        ),
      ),
    );
    if (mounted && !widget.demoMode) await _load();
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
    ], error: _playersError);
  }

  Widget _buildWalletPage() {
    return _buildPage('wallet', [
      SectionCard(
        title: 'Load Balance Requests',
        icon: Icons.account_balance_wallet_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send load balance or withdrawal requests as message threads. Admin can reply and attach files back to you.',
              style: TextStyle(color: AppColors.mutedText, height: 1.45),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryActionButton(
                    label: 'Load Balance',
                    onPressed: widget.demoMode
                        ? _demoAction
                        : () => _openWalletMessages('funding'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryActionButton(
                    label: 'Withdraw',
                    onPressed: widget.demoMode
                        ? _demoAction
                        : () => _openWalletMessages('withdrawal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ], error: _walletError);
  }

  void _openWalletMessages(String requestType) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletMessagesScreen(
          apiClient: widget.apiClient,
          initialRequestType: requestType,
        ),
      ),
    );
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
    ], error: _matchError);
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
    ], error: _recentMatchesError);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _homeError = null;
      _playersError = null;
      _walletError = null;
      _matchError = null;
      _recentMatchesError = null;
    });

    await Future.wait([
      _loadHomeSummary(),
      _loadPlayers(),
      _loadRecentMatches(),
      _loadToolbarData(),
    ]);

    if (mounted) {
      _syncPresenceHeartbeat();
      _syncChallengePolling();
      _syncNotificationSocket();
      setState(() => _loading = false);
    }
  }

  Future<void> _loadHomeSummary() async {
    try {
      final results = await Future.wait<Object>([
        widget.apiClient.getWalletBalance(),
        widget.apiClient.getPlayerProgress(),
      ]);
      if (!mounted) return;
      final progress = results[1] as PlayerProgress;
      setState(() {
        _balance = results[0] as double;
        _currentUserId = progress.userId;
        _rating = progress.rating;
        _level = progress.level;
        _homeError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _homeError = friendlyAppErrorMessage(
          error,
          action: 'load your account summary',
        );
      });
    }
  }

  Future<void> _loadPlayers() async {
    try {
      final users = await widget.apiClient.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _playersError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _playersError = friendlyAppErrorMessage(error, action: 'load players');
      });
    }
  }

  Future<void> _loadRecentMatches() async {
    try {
      final history = await widget.apiClient.getMatchHistory();
      if (!mounted) return;
      setState(() {
        _history = history
            .whereType<Map<String, dynamic>>()
            .map(MatchSummary.fromJson)
            .toList(growable: false);
        _recentMatchesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recentMatchesError = friendlyAppErrorMessage(
          error,
          action: 'load recent matches',
        );
      });
    }
  }

  Future<void> _loadToolbarData() async {
    try {
      final notifications = await widget.apiClient.getPlatformNotifications();
      if (mounted) {
        setState(() {
          _platformNotifications = notifications;
          _notificationUnreadCount = notifications
              .where((item) => !item.isRead)
              .length;
        });
      }
    } catch (_) {
      // Toolbar data retries in the background and should not cover a tab.
    }

    try {
      final isOnline = await widget.apiClient.getPresence();
      if (mounted) setState(() => _isOnline = isOnline);
    } catch (_) {
      // Keep the last known status until the presence heartbeat succeeds.
    }
  }

  Future<void> _loadDemoData() async {
    setState(() {
      _loading = true;
      _homeError = null;
      _playersError = null;
      _walletError = null;
      _matchError = null;
      _recentMatchesError = null;
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
      _platformNotifications = const [];
      _notificationUnreadCount = 0;
      _loading = false;
    });
  }

  void _demoAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo mode: API action disabled.')),
    );
  }

  Future<void> _showChallengeDialog(RegisteredUser user) async {
    final betController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();
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
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: betController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Bet amount',
                            helperText: 'Min 10, Max 100',
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null) {
                              return 'Enter a valid amount';
                            }
                            if (amount < 10 || amount > 100) {
                              return 'Bet amount must be between 10 and 100';
                            }
                            return null;
                          },
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
                          'Opponent match only: both wallets lock the bet after acceptance. The winner receives the full pot; puzzles and bot games never affect wallet balance.',
                        ),
                      ],
                    ),
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
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
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
      if (betAmount < 10 || betAmount > 100) {
        if (mounted) {
          setState(
            () => _playersError = 'Bet amount must be between 10 and 100.',
          );
        }
        return;
      }
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
        setState(() {
          _playersError = friendlyAppErrorMessage(
            e,
            action: 'send this challenge',
          );
        });
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

  void _syncNotificationSocket() {
    _notificationReconnectTimer?.cancel();
    if (widget.demoMode || !_isOnline) {
      _disconnectNotificationSocket();
      return;
    }
    _connectNotificationSocket();
  }

  void _connectNotificationSocket() {
    if (_notificationSocketConnecting || widget.demoMode || !_isOnline) {
      return;
    }

    _notificationSocketConnecting = true;
    try {
      _notificationSubscription?.cancel();
      _notificationSubscription = null;
      _notificationChannel?.sink.close();

      final channel = WebSocketChannel.connect(
        Uri.parse(widget.apiClient.notificationSocketUrl),
      );
      _notificationChannel = channel;
      _notificationSubscription = channel.stream.listen(
        _handleNotificationSocketEvent,
        onError: (_) => _scheduleNotificationReconnect(),
        onDone: _scheduleNotificationReconnect,
      );
    } catch (_) {
      _scheduleNotificationReconnect();
    } finally {
      _notificationSocketConnecting = false;
    }
  }

  void _disconnectNotificationSocket() {
    _notificationReconnectTimer?.cancel();
    _notificationReconnectTimer = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notificationChannel?.sink.close();
    _notificationChannel = null;
  }

  void _scheduleNotificationReconnect() {
    if (!mounted || widget.demoMode || !_isOnline) {
      return;
    }

    _notificationReconnectTimer?.cancel();
    _notificationReconnectTimer = Timer(
      const Duration(seconds: 5),
      _connectNotificationSocket,
    );
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

  Future<void> _reloadNotificationsFromApi() async {
    if (widget.demoMode) return;
    final notifications = await widget.apiClient.getPlatformNotifications();
    if (!mounted) return;
    setState(() {
      _platformNotifications = notifications;
      _notificationUnreadCount = notifications
          .where((item) => !item.isRead)
          .length;
    });
  }

  void _handleNotificationSocketEvent(dynamic event) {
    if (!mounted) return;

    try {
      final payload = event is String ? jsonDecode(event) : event;
      if (payload is! Map<String, dynamic>) return;

      final eventName = payload['event']?.toString() ?? '';
      if (eventName == 'notification.deleted') {
        final deletedId = int.tryParse(payload['id']?.toString() ?? '');
        if (deletedId == null) return;
        setState(() {
          _platformNotifications = _platformNotifications
              .where((item) => item.id != deletedId)
              .toList(growable: false);
          _notificationUnreadCount = _platformNotifications
              .where((item) => !item.isRead)
              .length;
        });
        return;
      }

      final rawNotification = payload['notification'];
      if (rawNotification is! Map<String, dynamic>) return;
      final currentItem = PlatformNotificationItem.fromJson(rawNotification);
      if (!currentItem.isActive) {
        setState(() {
          _platformNotifications = _platformNotifications
              .where((item) => item.id != currentItem.id)
              .toList(growable: false);
          _notificationUnreadCount = _platformNotifications
              .where((item) => !item.isRead)
              .length;
        });
        return;
      }

      final existingIndex = _platformNotifications.indexWhere(
        (item) => item.id == currentItem.id,
      );
      final nextItem = PlatformNotificationItem(
        id: currentItem.id,
        noticeType: currentItem.noticeType,
        title: currentItem.title,
        body: currentItem.body,
        actionLabel: currentItem.actionLabel,
        actionUrl: currentItem.actionUrl,
        isActive: currentItem.isActive,
        isRead: existingIndex >= 0
            ? _platformNotifications[existingIndex].isRead
            : false,
        createdAt: currentItem.createdAt,
      );

      setState(() {
        final nextNotifications = [..._platformNotifications];
        if (existingIndex >= 0) {
          nextNotifications[existingIndex] = nextItem;
        } else {
          nextNotifications.insert(0, nextItem);
        }
        _platformNotifications = nextNotifications;
        _notificationUnreadCount = nextNotifications
            .where((item) => !item.isRead)
            .length;
      });
    } catch (_) {
      // Ignore malformed websocket messages and keep the socket alive.
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

  Future<void> _showPlatformNotifications() async {
    if (widget.demoMode) {
      _demoAction();
      return;
    }

    if (_platformNotifications.isEmpty) {
      await _reloadNotificationsFromApi();
    }
    if (!mounted) return;

    final currentNotifications = _platformNotifications;
    if (currentNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No admin notifications yet.')),
      );
      return;
    }

    final seenNotifications = await widget.apiClient
        .markPlatformNotificationsSeen();
    if (!mounted) return;
    setState(() {
      _platformNotifications = seenNotifications;
      _notificationUnreadCount = 0;
    });

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Admin Notifications',
                  style: TextStyle(
                    color: AppColors.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Announcements, offers, and messages from admin appear here in real time.',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentNotifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = currentNotifications[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          _handleNotificationAction(item);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDE9FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _StatusChip(
                                    label: item.noticeType.toUpperCase(),
                                    background: const Color(0xFFE8FFF2),
                                    foreground: const Color(0xFF16794C),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        color: AppColors.heading,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  color: AppColors.heading,
                                  height: 1.35,
                                ),
                              ),
                              if (item.actionLabel != null ||
                                  item.actionUrl != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  [
                                    if (item.actionLabel != null)
                                      item.actionLabel,
                                    if (item.actionUrl != null) item.actionUrl,
                                  ].whereType<String>().join(' • '),
                                  style: const TextStyle(
                                    color: AppColors.deepPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleNotificationAction(PlatformNotificationItem item) async {
    final actionUrl = item.actionUrl?.trim();
    if (actionUrl == null || actionUrl.isEmpty) {
      return;
    }

    if (actionUrl.startsWith('app://wallet/load-balance')) {
      _openWalletMessages('funding');
      return;
    }

    if (actionUrl.startsWith('app://wallet/withdraw')) {
      _openWalletMessages('withdrawal');
      return;
    }

    if (actionUrl.startsWith('app://players')) {
      if (mounted) {
        setState(() => _selectedIndex = 1);
      }
      return;
    }

    if (actionUrl.startsWith('app://match')) {
      if (mounted) {
        setState(() => _selectedIndex = 3);
      }
      return;
    }

    if (actionUrl.startsWith('app://home')) {
      if (mounted) {
        setState(() => _selectedIndex = 0);
      }
    }
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
          'On acceptance, the stake is locked from both wallets.'
          '\nWinner receives the full pot. Bot and puzzle games never affect wallets.',
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
      if (mounted) {
        setState(() {
          _matchError = friendlyAppErrorMessage(
            error,
            action: action == 'reject'
                ? 'reject this challenge'
                : 'accept this challenge',
          );
        });
      }
    } finally {
      if (mounted) await _pollMatches();
    }
  }

  Future<void> _openNetworkMatch(LiveMatch match) async {
    final userId = _currentUserId;
    if (!mounted || userId == null) return;
    if (match.status != 'active' || match.acceptedAt == null) {
      setState(
        () => _matchError = 'Waiting for the challenged player to accept.',
      );
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
      });
      _syncPresenceHeartbeat();
      _syncChallengePolling();
      _syncNotificationSocket();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated ? 'You are now online' : 'You are now offline'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyAppErrorMessage(
                error,
                action: 'update your online status',
              ),
            ),
          ),
        );
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
}

enum ChessActivity { puzzles, dailyPuzzle, bots }

const _dailyPuzzleCompletionKey = 'daily_puzzle_completed_date';
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatPuzzleDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

String _dailyDateStorageValue(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ChessActivityScreen extends StatefulWidget {
  const ChessActivityScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activity,
    required this.initialBoardVariant,
    this.initialFen,
    this.randomizePuzzles = true,
    this.apiClient,
    this.initialRating = 0,
    this.initialLevel = 0,
  });

  final String title;
  final String subtitle;
  final ChessActivity activity;
  final int initialBoardVariant;
  final String? initialFen;
  final bool randomizePuzzles;
  final ApiClient? apiClient;
  final int initialRating;
  final int initialLevel;

  @override
  State<ChessActivityScreen> createState() => _ChessActivityScreenState();
}

class _ChessActivityScreenState extends State<ChessActivityScreen> {
  late chess.Chess _game;
  late int _puzzleIndex;
  ChessPuzzle? _generatedPuzzle;
  late final DateTime _dailyDate;
  String _botLevel = 'Beginner';
  String? _selectedSquare;
  Set<String> _legalTargets = const {};
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _notice;
  bool _puzzleSolved = false;
  bool _botThinking = false;
  bool _puzzleReplying = false;
  bool _puzzleAwarding = false;
  bool _botWinReported = false;
  int _solutionStep = 0;
  late int _rating;
  late int _playerLevel;
  late String _botGameId;
  Timer? _homeRedirectTimer;
  Timer? _puzzleReplyTimer;
  final ChessBotEngine _botEngine = ChessBotEngine();
  final Random _puzzleRandom = Random();

  bool get _isBot => widget.activity == ChessActivity.bots;
  ChessPuzzle get _puzzle =>
      _generatedPuzzle ?? chessPuzzles[_puzzleIndex % chessPuzzles.length];

  @override
  void initState() {
    super.initState();
    _dailyDate = DateTime.now();
    _rating = widget.initialRating;
    _playerLevel = widget.initialLevel;
    _puzzleIndex = widget.initialBoardVariant % chessPuzzles.length;
    if (widget.activity == ChessActivity.dailyPuzzle) {
      _generatedPuzzle = dailyChessPuzzle(_dailyDate);
      unawaited(_loadDailyCompletion());
    } else if (widget.activity == ChessActivity.puzzles &&
        widget.randomizePuzzles) {
      _generatedPuzzle = generateRandomChessLesson(_puzzleRandom);
    }
    _resetGame(notify: false);
  }

  @override
  void dispose() {
    _homeRedirectTimer?.cancel();
    _puzzleReplyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        toolbarHeight: 52,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.heading,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 18),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          if (_isBot) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DropdownButtonFormField<String>(
                key: ValueKey(_botLevel),
                initialValue: _botLevel,
                decoration: InputDecoration(
                  labelText: 'Bot difficulty',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: const Icon(Icons.smart_toy_outlined, size: 20),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 38,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ChessBotEngine.profileFor(_botLevel).description,
                  key: const Key('bot-difficulty-description'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Level $_playerLevel',
                  key: const Key('bot-player-level'),
                  style: const TextStyle(
                    color: AppColors.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _GameStatusBar(
              message: _statusMessage,
              isPositive: _puzzleSolved || _game.in_checkmate,
              isThinking: _botThinking,
            ),
          ),
          const SizedBox(height: 7),
          if (!_isBot) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _PuzzleChip(
                    icon: Icons.lightbulb_rounded,
                    label: _puzzle.theme,
                  ),
                  const SizedBox(width: 6),
                  _PuzzleChip(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: _puzzle.difficulty,
                  ),
                  const Spacer(),
                  Text(
                    widget.activity == ChessActivity.dailyPuzzle
                        ? _formatPuzzleDate(_dailyDate)
                        : widget.randomizePuzzles
                        ? 'Endless random'
                        : '${_puzzleIndex + 1}/${chessPuzzles.length}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 3),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Rating $_rating',
                  key: const Key('puzzle-player-rating'),
                  style: const TextStyle(
                    color: AppColors.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: AspectRatio(
                aspectRatio: 1,
                child: InteractiveChessBoard(
                  game: _game,
                  selectedSquare: _selectedSquare,
                  legalTargets: _legalTargets,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  enabled:
                      !_botThinking &&
                      !_puzzleReplying &&
                      !_puzzleSolved &&
                      !_game.game_over,
                  onSquareTap: _handleSquareTap,
                  onMove: _tryMove,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BoardControl(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onPressed:
                      !_isBot || _game.getHistory().isEmpty || _botThinking
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
                  label: _puzzleSolved
                      ? widget.activity == ChessActivity.dailyPuzzle
                            ? 'Done'
                            : 'Random'
                      : 'Reset',
                  onPressed: _puzzleSolved
                      ? widget.activity == ChessActivity.dailyPuzzle
                            ? () => Navigator.of(context).pop()
                            : _nextPuzzle
                      : _resetGame,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MoveHistory(moves: _game.getHistory().whereType<String>().toList()),
        ],
      ),
    );
  }

  String get _statusMessage {
    if (_puzzleReplying) return 'Opponent is responding…';
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
    if (_botThinking || _puzzleReplying || _puzzleSolved || _game.game_over) {
      return;
    }
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

    if (!_isBot && uci != _puzzle.solutionLine[_solutionStep]) {
      _game.undo();
      setState(() {
        _selectedSquare = null;
        _legalTargets = const {};
        _notice = 'That move is legal, but it is not the best move. Try again.';
      });
      return;
    }

    final puzzleMoveCompleted = !_isBot;
    if (puzzleMoveCompleted) _solutionStep++;
    final solved =
        puzzleMoveCompleted && _solutionStep >= _puzzle.solutionLine.length;
    setState(() {
      _selectedSquare = null;
      _legalTargets = const {};
      _lastMoveFrom = from;
      _lastMoveTo = to;
      _notice = _isBot
          ? null
          : solved
          ? 'Correct! ${_puzzle.explanation}'
          : 'Good move. Watch the reply…';
      _puzzleSolved = solved;
    });

    if (!_isBot && !solved) {
      _playPuzzleReply();
    } else if (solved) {
      unawaited(_awardPuzzleCompletion());
    } else if (_isBot &&
        _game.in_checkmate &&
        _game.turn == chess.Color.BLACK) {
      unawaited(_handlePlayerWin());
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
    if (widget.randomizePuzzles) {
      final previousFen = _puzzle.fen;
      do {
        _generatedPuzzle = generateRandomChessLesson(_puzzleRandom);
      } while (_generatedPuzzle!.fen == previousFen);
    } else {
      _puzzleIndex = randomPuzzleIndex(_puzzleRandom, excluding: _puzzleIndex);
    }
    _resetGame();
  }

  Future<void> _loadDailyCompletion() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted ||
        preferences.getString(_dailyPuzzleCompletionKey) !=
            _dailyDateStorageValue(_dailyDate)) {
      return;
    }
    setState(() {
      _puzzleSolved = true;
      _notice =
          'Completed for ${_formatPuzzleDate(_dailyDate)}. A new Daily Puzzle unlocks tomorrow.';
    });
  }

  Future<void> _completeDailyPuzzle({required bool ratingAwarded}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _dailyPuzzleCompletionKey,
      _dailyDateStorageValue(_dailyDate),
    );
    if (!mounted) return;
    final tomorrow = _dailyDate.add(const Duration(days: 1));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('daily-puzzle-complete-toast'),
        content: Text(
          'Daily Puzzle completed for ${_formatPuzzleDate(_dailyDate)}. '
          '${ratingAwarded ? 'Rating +1. ' : ''}'
          'A new puzzle will unlock tomorrow, ${_formatPuzzleDate(tomorrow)}.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF16794C),
      ),
    );
  }

  Future<void> _awardPuzzleCompletion() async {
    if (_puzzleAwarding) return;
    _puzzleAwarding = true;
    try {
      final progress = widget.apiClient == null
          ? (awarded: true, rating: _rating + 1, level: _playerLevel)
          : await _completePuzzleOnServer();
      if (!mounted) return;
      setState(() {
        _rating = progress.rating;
        _playerLevel = progress.level;
      });

      if (widget.activity == ChessActivity.dailyPuzzle) {
        await _completeDailyPuzzle(ratingAwarded: progress.awarded);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('puzzle-rating-toast'),
            content: Text(
              progress.awarded
                  ? 'Puzzle completed! Rating +1. Your rating is ${progress.rating}.'
                  : 'This puzzle was already rewarded. Rating ${progress.rating}.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF16794C),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _notice = friendlyAppErrorMessage(
            error,
            action: 'save your puzzle reward',
          );
        });
      }
    } finally {
      _puzzleAwarding = false;
    }
  }

  Future<({bool awarded, int rating, int level})>
  _completePuzzleOnServer() async {
    final progress = await widget.apiClient!.completePuzzle(
      puzzleId: _puzzle.id,
      theme: _puzzle.theme,
    );
    return (
      awarded: progress.awarded,
      rating: progress.rating,
      level: progress.level,
    );
  }

  void _playPuzzleReply() {
    _puzzleReplyTimer?.cancel();
    setState(() => _puzzleReplying = true);
    _puzzleReplyTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _solutionStep >= _puzzle.solutionLine.length) return;
      final response = _puzzle.solutionLine[_solutionStep];
      final from = response.substring(0, 2);
      final to = response.substring(2, 4);
      final moved = _game.move({'from': from, 'to': to, 'promotion': 'q'});
      if (!moved) {
        setState(() {
          _puzzleReplying = false;
          _notice = 'This puzzle could not continue. Try another puzzle.';
        });
        return;
      }
      _solutionStep++;
      setState(() {
        _lastMoveFrom = from;
        _lastMoveTo = to;
        _puzzleReplying = false;
        _notice = 'Opponent replied. Find the next best move.';
      });
    });
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
    _puzzleReplying = false;
    _solutionStep = 0;
    _puzzleReplyTimer?.cancel();
    _botThinking = false;
    if (_isBot) {
      _botGameId =
          '${DateTime.now().microsecondsSinceEpoch}-${_puzzleRandom.nextInt(1 << 32)}';
      _botWinReported = false;
    }
    if (notify && mounted) setState(() {});
  }

  Future<void> _handlePlayerWin() async {
    if (_botWinReported) return;
    _botWinReported = true;
    try {
      final progress = widget.apiClient == null
          ? (awarded: true, rating: _rating, level: _playerLevel + 1)
          : await _completeBotGameOnServer();
      if (!mounted) return;
      setState(() {
        _rating = progress.rating;
        _playerLevel = progress.level;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('level-up-toast'),
          content: Text(
            progress.awarded
                ? 'Bot defeated! Level +1. You are now Level ${progress.level}.'
                : 'This bot game was already rewarded. Level ${progress.level}.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF16794C),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _notice = friendlyAppErrorMessage(
            error,
            action: 'save your bot-game reward',
          );
        });
      }
      return;
    }
    _homeRedirectTimer?.cancel();
    _homeRedirectTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<({bool awarded, int rating, int level})>
  _completeBotGameOnServer() async {
    final progress = await widget.apiClient!.completeBotGame(
      gameId: _botGameId,
      difficulty: _botLevel,
    );
    return (
      awarded: progress.awarded,
      rating: progress.rating,
      level: progress.level,
    );
  }
}

class _PuzzleChip extends StatelessWidget {
  const _PuzzleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.deepPurple),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.deepPurple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFE8FFF2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? const Color(0xFFB7E6C8) : const Color(0xFFDDE9FF),
        ),
      ),
      child: Row(
        children: [
          if (isThinking)
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isPositive ? Icons.check_circle_rounded : Icons.circle,
              color: isPositive
                  ? const Color(0xFF16794C)
                  : const Color(0xFF63A83B),
              size: 17,
            ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              key: const Key('game-status'),
              style: const TextStyle(
                color: AppColors.heading,
                fontSize: 13,
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
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 3),
          Text(
            moves.isEmpty ? 'No moves yet' : moves.join('  '),
            key: const Key('move-history'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedText,
              height: 1.25,
              fontSize: 12,
            ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
