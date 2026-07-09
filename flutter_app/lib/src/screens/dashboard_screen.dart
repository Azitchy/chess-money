import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../dashboard_widgets.dart';
import '../match_summary.dart';
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
  bool _loading = true;
  String? _error;
  double _balance = 0;
  List<MatchSummary> _history = const [];

  final _fundAmount = TextEditingController();
  final _fundNote = TextEditingController();

  final _mode = ValueNotifier<String>('casual');
  final _timeControl = ValueNotifier<String>('blitz');
  final _betAmount = TextEditingController(text: '0');
  final _matchId = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _loadDemoData();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _fundAmount.dispose();
    _fundNote.dispose();
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
          widget.demoMode ? 'Dashboard (Demo)' : 'Dashboard',
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
          : RefreshIndicator(
              color: AppColors.blue,
              onRefresh: widget.demoMode ? () async {} : _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  HeroHeader(
                    demoMode: widget.demoMode,
                    balance: _balance,
                    historyCount: _history.length,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    ErrorBanner(message: _error!),
                  ],
                  if (widget.demoMode) ...[
                    const SizedBox(height: 14),
                    const DemoBanner(),
                  ],
                  const SizedBox(height: 16),
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
                          onPressed: widget.demoMode
                              ? _demoAction
                              : _requestFunds,
                        ),
                      ],
                    ),
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
                            DropdownMenuItem(
                              value: 'casual',
                              child: Text('Casual'),
                            ),
                            DropdownMenuItem(
                              value: 'competitive',
                              child: Text('Competitive'),
                            ),
                          ],
                          onChanged: (v) => _mode.value = v ?? 'casual',
                        ),
                        const SizedBox(height: 12),
                        DashboardDropdownField<String>(
                          label: 'Time control',
                          valueListenable: _timeControl,
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
                          onChanged: (v) => _timeControl.value = v ?? 'blitz',
                        ),
                        const SizedBox(height: 12),
                        DashboardInputField(
                          controller: _betAmount,
                          label: 'Bet amount',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        PrimaryActionButton(
                          label: 'Create Match',
                          onPressed: widget.demoMode
                              ? _demoAction
                              : _createMatch,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              onPressed: widget.demoMode
                                  ? _demoAction
                                  : _joinMatch,
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
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Recent Matches',
                    icon: Icons.history_rounded,
                    child: Column(
                      children: _history.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No matches yet.'),
                              ),
                            ]
                          : _history
                                .map((item) => MatchTile(match: item))
                                .toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final balance = await widget.apiClient.getWalletBalance();
      final history = await widget.apiClient.getMatchHistory();
      setState(() {
        _balance = balance;
        _history = history
            .whereType<Map<String, dynamic>>()
            .map(MatchSummary.fromJson)
            .toList(growable: false);
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
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match #${created['id']} created')),
        );
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

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
