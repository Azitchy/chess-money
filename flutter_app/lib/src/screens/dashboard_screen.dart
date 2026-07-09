import 'package:flutter/material.dart';

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
  static const _blue = Color(0xFF49A6F4);
  static const _lavender = Color(0xFF7B74F7);
  static const _deepPurple = Color(0xFF4D3FD9);
  static const _pageBg = Color(0xFFF4F9FF);

  bool _loading = true;
  String? _error;
  double _balance = 0;
  List<dynamic> _history = const [];

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
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.demoMode ? 'Dashboard (Demo)' : 'Dashboard',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2456A6),
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
            color: _deepPurple,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _blue,
              onRefresh: widget.demoMode ? () async {} : _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _HeroHeader(
                    demoMode: widget.demoMode,
                    balance: _balance,
                    historyCount: _history.length,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: _error!),
                  ],
                  if (widget.demoMode) ...[
                    const SizedBox(height: 14),
                    const _DemoBanner(),
                  ],
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Request Wallet Funding',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      children: [
                        _InputField(
                          controller: _fundAmount,
                          label: 'Amount',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          controller: _fundNote,
                          label: 'Note (optional)',
                        ),
                        const SizedBox(height: 14),
                        _PrimaryButton(
                          label: 'Send Request',
                          onPressed: widget.demoMode
                              ? _demoAction
                              : _requestFunds,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Create Match',
                    icon: Icons.sports_esports_outlined,
                    child: Column(
                      children: [
                        _DropdownField<String>(
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
                        _DropdownField<String>(
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
                        _InputField(
                          controller: _betAmount,
                          label: 'Bet amount',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _PrimaryButton(
                          label: 'Create Match',
                          onPressed: widget.demoMode
                              ? _demoAction
                              : _createMatch,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Join / End Match',
                    icon: Icons.call_merge_outlined,
                    child: Column(
                      children: [
                        _InputField(
                          controller: _matchId,
                          label: 'Match ID',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MiniButton(
                              label: 'Join',
                              onPressed: widget.demoMode
                                  ? _demoAction
                                  : _joinMatch,
                            ),
                            _MiniButton(
                              label: 'P1 Win',
                              onPressed: widget.demoMode
                                  ? _demoAction
                                  : () => _endMatch('player1_win'),
                            ),
                            _MiniButton(
                              label: 'P2 Win',
                              onPressed: widget.demoMode
                                  ? _demoAction
                                  : () => _endMatch('player2_win'),
                            ),
                            _MiniButton(
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
                  _SectionCard(
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
                                .map(
                                  (item) => _MatchTile(
                                    id: item['id'],
                                    status: item['status'],
                                    mode: item['mode'],
                                    betAmount: item['bet_amount'],
                                    winnerId: item['winner_id'],
                                  ),
                                )
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
        _history = history;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDemoData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    setState(() {
      _balance = 128.50;
      _history = [
        {
          'id': 101,
          'status': 'completed',
          'mode': 'casual',
          'bet_amount': 0,
          'winner_id': null,
        },
        {
          'id': 102,
          'status': 'active',
          'mode': 'competitive',
          'bet_amount': 25,
          'winner_id': null,
        },
      ];
      _loading = false;
    });
  }

  Future<void> _requestFunds() async {
    try {
      await widget.apiClient.requestFunds(
        double.parse(_fundAmount.text.trim()),
        note: _fundNote.text.trim().isEmpty ? null : _fundNote.text.trim(),
      );
      await _load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Funding request sent')));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _joinMatch() async {
    try {
      await widget.apiClient.joinMatch(int.parse(_matchId.text.trim()));
      await _load();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _endMatch(String result) async {
    try {
      await widget.apiClient.endMatch(int.parse(_matchId.text.trim()), result);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _demoAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo mode: API action disabled.')),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.demoMode,
    required this.balance,
    required this.historyCount,
  });

  final bool demoMode;
  final double balance;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF61B6FF), Color(0xFF7B74F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3349A6F4),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  demoMode ? 'Demo Mode' : 'Ready to play',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  demoMode
                      ? 'You are viewing the dashboard without logging in.'
                      : 'Manage your wallet and matches from one place.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5E7FF)),
      ),
      child: const Text(
        'Demo mode is on. API calls are disabled so you can review the home screen UI.',
        style: TextStyle(color: Color(0xFF355C9A), fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDDE9FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF49A6F4), Color(0xFF7B74F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2456A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF49A6F4), width: 1.6),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.valueListenable,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final ValueNotifier<T> valueListenable;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: valueListenable,
      builder: (_, value, __) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFFF7FAFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFDCE9FF)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
              iconEnabledColor: _blue,
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_blue, _lavender]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3349A6F4),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF0F5FF),
        foregroundColor: const Color(0xFF2456A6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCED5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.id,
    required this.status,
    required this.mode,
    required this.betAmount,
    required this.winnerId,
  });

  final dynamic id;
  final dynamic status;
  final dynamic mode;
  final dynamic betAmount;
  final dynamic winnerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE9FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF49A6F4), Color(0xFF7B74F7)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match #$id',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2456A6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mode: $mode • Bet: $betAmount',
                  style: const TextStyle(color: Color(0xFF6D87B7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$status',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4D3FD9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Winner: ${winnerId ?? '-'}',
                style: const TextStyle(color: Color(0xFF6D87B7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
