import 'package:flutter/material.dart';

import '../services/api_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiClient,
    required this.onLogout,
  });

  final ApiClient apiClient;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    _load();
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
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.apiClient.logout();
              widget.onLogout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Wallet Balance: \$${_balance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('Request Wallet Funding'),
                  TextField(
                    controller: _fundAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  TextField(
                    controller: _fundNote,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _requestFunds,
                    child: const Text('Send Request'),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Create Match'),
                  ValueListenableBuilder<String>(
                    valueListenable: _mode,
                    builder: (_, value, __) => DropdownButton<String>(
                      value: value,
                      isExpanded: true,
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
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _timeControl,
                    builder: (_, value, __) => DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'bullet',
                          child: Text('Bullet'),
                        ),
                        DropdownMenuItem(value: 'blitz', child: Text('Blitz')),
                        DropdownMenuItem(value: 'rapid', child: Text('Rapid')),
                        DropdownMenuItem(
                          value: 'classical',
                          child: Text('Classical'),
                        ),
                      ],
                      onChanged: (v) => _timeControl.value = v ?? 'blitz',
                    ),
                  ),
                  TextField(
                    controller: _betAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Bet amount'),
                  ),
                  ElevatedButton(
                    onPressed: _createMatch,
                    child: const Text('Create Match'),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Join / End Match'),
                  TextField(
                    controller: _matchId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Match ID'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _joinMatch,
                        child: const Text('Join'),
                      ),
                      ElevatedButton(
                        onPressed: () => _endMatch('player1_win'),
                        child: const Text('P1 Win'),
                      ),
                      ElevatedButton(
                        onPressed: () => _endMatch('player2_win'),
                        child: const Text('P2 Win'),
                      ),
                      ElevatedButton(
                        onPressed: () => _endMatch('draw'),
                        child: const Text('Draw'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Recent Matches'),
                  ..._history.map(
                    (item) => ListTile(
                      title: Text('Match #${item['id']} - ${item['status']}'),
                      subtitle: Text(
                        'Mode: ${item['mode']} | Bet: ${item['bet_amount']} | Winner: ${item['winner_id'] ?? '-'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );

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
}
