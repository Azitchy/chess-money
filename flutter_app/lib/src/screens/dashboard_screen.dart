import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../dashboard_widgets.dart';
import '../match_summary.dart';
import '../registered_user.dart';
import '../services/api_client.dart';

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
    'Join / End Match',
    'Recent Matches',
  ];

  bool _loading = true;
  int _selectedIndex = 0;
  String? _error;
  double _balance = 0;
  List<MatchSummary> _history = const [];
  List<RegisteredUser> _users = const [];
  RegisteredUser? _selectedOpponent;

  final _fundAmount = TextEditingController();
  final _fundNote = TextEditingController();
  final _playerSearch = TextEditingController();

  final _mode = ValueNotifier<String>('casual');
  final _timeControl = ValueNotifier<String>('blitz');
  final _betAmount = TextEditingController(text: '0');
  final _matchId = TextEditingController();

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
    _playerSearch.removeListener(_handleSearchChanged);
    _fundAmount.dispose();
    _fundNote.dispose();
    _playerSearch.dispose();
    _mode.dispose();
    _timeControl.dispose();
    _betAmount.dispose();
    _matchId.dispose();
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

    return _buildPage('home', [
      HeroHeader(
        demoMode: widget.demoMode,
        balance: _balance,
        historyCount: _history.length,
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Create Match',
        icon: Icons.sports_esports_outlined,
        child: Column(
          children: [
            DashboardDropdownField<String>(
              label: 'Mode',
              valueListenable: _mode,
              items: const [
                DropdownMenuItem(value: 'casual', child: Text('Casual')),
                DropdownMenuItem(
                  value: 'competitive',
                  child: Text('Competitive'),
                ),
              ],
              onChanged: (value) => _mode.value = value ?? 'casual',
            ),
            const SizedBox(height: 12),
            DashboardDropdownField<String>(
              label: 'Time control',
              valueListenable: _timeControl,
              items: const [
                DropdownMenuItem(value: 'bullet', child: Text('Bullet')),
                DropdownMenuItem(value: 'blitz', child: Text('Blitz')),
                DropdownMenuItem(value: 'rapid', child: Text('Rapid')),
                DropdownMenuItem(value: 'classical', child: Text('Classical')),
              ],
              onChanged: (value) => _timeControl.value = value ?? 'blitz',
            ),
            const SizedBox(height: 12),
            DashboardInputField(
              controller: _betAmount,
              label: 'Bet amount',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DashboardInputField(
              controller: _playerSearch,
              label: 'Search online player',
            ),
            const SizedBox(height: 12),
            if (_selectedOpponent != null) ...[
              _SelectedOpponentBanner(
                user: _selectedOpponent!,
                onClear: () => setState(() => _selectedOpponent = null),
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                onlinePlayers.isEmpty
                    ? 'No online players found.'
                    : 'Online players (${onlinePlayers.length})',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...onlinePlayers.map(
              (user) => PlayerTile(
                user: user,
                selected: _selectedOpponent?.id == user.id,
                buttonLabel: _selectedOpponent?.id == user.id
                    ? 'Selected'
                    : 'Select',
                onChallenge: () => _selectOpponent(user),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
              label: _selectedOpponent == null
                  ? 'Create Match'
                  : 'Create Match vs @${_selectedOpponent!.username}',
              onPressed: widget.demoMode ? _demoAction : _createMatch,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildPlayersPage() {
    final onlinePlayers = _filteredOnlinePlayers;

    return _buildPage('players', [
      SectionCard(
        title: 'Online Players',
        icon: Icons.people_alt_outlined,
        child: Column(
          children: [
            DashboardInputField(
              controller: _playerSearch,
              label: 'Search online player',
            ),
            if (_selectedOpponent != null) ...[
              const SizedBox(height: 12),
              _SelectedOpponentBanner(
                user: _selectedOpponent!,
                onClear: () => setState(() => _selectedOpponent = null),
              ),
            ],
            const SizedBox(height: 12),
            if (onlinePlayers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No online players found right now.'),
              )
            else
              ...onlinePlayers.map(
                (user) => PlayerTile(
                  user: user,
                  selected: _selectedOpponent?.id == user.id,
                  buttonLabel: _selectedOpponent?.id == user.id
                      ? 'Selected'
                      : 'Play',
                  onChallenge: () => _selectOpponent(user, moveToHome: true),
                ),
              ),
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
        title: 'Join / End Match',
        icon: Icons.call_merge_outlined,
        child: Column(
          children: [
            DashboardInputField(
              controller: _matchId,
              label: 'Match ID',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MiniActionButton(
                  label: 'Join',
                  onPressed: widget.demoMode ? _demoAction : _joinMatch,
                ),
                MiniActionButton(
                  label: 'P1 Win',
                  onPressed: widget.demoMode
                      ? _demoAction
                      : () => _endMatch('player1_win'),
                ),
                MiniActionButton(
                  label: 'P2 Win',
                  onPressed: widget.demoMode
                      ? _demoAction
                      : () => _endMatch('player2_win'),
                ),
                MiniActionButton(
                  label: 'Draw',
                  onPressed: widget.demoMode
                      ? _demoAction
                      : () => _endMatch('draw'),
                ),
              ],
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
      final history = await widget.apiClient.getMatchHistory();
      final users = await widget.apiClient.getUsers();
      setState(() {
        _balance = balance;
        _history = history
            .whereType<Map<String, dynamic>>()
            .map(MatchSummary.fromJson)
            .toList(growable: false);
        _users = users;
        _selectedOpponent = _syncSelectedOpponent(users);
      });
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

  Future<void> _createMatch() async {
    try {
      final created = await widget.apiClient.createMatch(
        mode: _mode.value,
        betAmount: double.parse(_betAmount.text.trim()),
        timeControl: _timeControl.value,
        opponentId: _selectedOpponent?.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedOpponent == null
                  ? 'Match #${created['id']} created'
                  : 'Match #${created['id']} created for @${_selectedOpponent!.username}',
            ),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _playerSearch.clear();
          _selectedOpponent = null;
        });
      }
      await _load();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    }
  }

  Future<void> _joinMatch() async {
    try {
      await widget.apiClient.joinMatch(int.parse(_matchId.text.trim()));
      await _load();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    }
  }

  Future<void> _endMatch(String result) async {
    try {
      await widget.apiClient.endMatch(int.parse(_matchId.text.trim()), result);
      await _load();
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
                        value: timeControl,
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
      await widget.apiClient.createMatch(
        mode: 'competitive',
        betAmount: betAmount,
        timeControl: timeControl,
        opponentId: user.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Challenge sent to @${user.username}')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      betController.dispose();
    }
  }

  List<RegisteredUser> get _onlinePlayers =>
      _users.where((user) => user.isOnline).toList(growable: false);

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

  RegisteredUser? _syncSelectedOpponent(List<RegisteredUser> users) {
    final selectedId = _selectedOpponent?.id;
    if (selectedId == null) {
      return null;
    }

    for (final user in users) {
      if (user.id == selectedId && user.isOnline) {
        return user;
      }
    }

    return null;
  }

  void _selectOpponent(RegisteredUser user, {bool moveToHome = false}) {
    setState(() {
      _selectedOpponent = user;
      _playerSearch.text = user.username;
      if (moveToHome) {
        _selectedIndex = 0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('@${user.username} selected for the next match')),
    );
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

class _SelectedOpponentBanner extends StatelessWidget {
  const _SelectedOpponentBanner({required this.user, required this.onClear});

  final RegisteredUser user;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FFF2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB7E6C8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16794C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Playing against ${user.name} (@${user.username})',
              style: const TextStyle(
                color: Color(0xFF16794C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Change')),
        ],
      ),
    );
  }
}
