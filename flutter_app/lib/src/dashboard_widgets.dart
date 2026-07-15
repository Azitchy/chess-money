import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'match_summary.dart';
import 'registered_user.dart';

class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeroChip(
                      label: 'Balance',
                      value: '\$${balance.toStringAsFixed(2)}',
                    ),
                    _HeroChip(label: 'Matches', value: '$historyCount'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

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

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
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
                    colors: [AppColors.blue, AppColors.lavender],
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
                  color: AppColors.heading,
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

class DashboardInputField extends StatelessWidget {
  const DashboardInputField({
    super.key,
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
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
      ),
    );
  }
}

class DashboardDropdownField<T> extends StatelessWidget {
  const DashboardDropdownField({
    super.key,
    required this.label,
    required this.valueListenable,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final ValueListenable<T> valueListenable;
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
              iconEnabledColor: AppColors.blue,
            ),
          ),
        );
      },
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.blue, AppColors.lavender],
          ),
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

class MiniActionButton extends StatelessWidget {
  const MiniActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF0F5FF),
        foregroundColor: AppColors.heading,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

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

class MatchTile extends StatelessWidget {
  const MatchTile({super.key, required this.match});

  final MatchSummary match;

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
                colors: [AppColors.blue, AppColors.lavender],
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
                  'Match #${match.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mode: ${match.mode} • Bet: ${match.betAmount}',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                match.status,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepPurple,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Winner: ${match.winnerId ?? '-'}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({
    super.key,
    required this.user,
    required this.onChallenge,
    this.buttonLabel = 'Challenge',
    this.selected = false,
  });

  final RegisteredUser user;
  final VoidCallback onChallenge;
  final String buttonLabel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.blue : const Color(0xFFDDE9FF),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.lavender],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: user.isOnline ? 'Online' : 'Offline',
                      background: user.isOnline
                          ? const Color(0xFFE8FFF2)
                          : const Color(0xFFF1F5F9),
                      foreground: user.isOnline
                          ? const Color(0xFF16794C)
                          : const Color(0xFF475569),
                    ),
                    if (user.lastSeenAt != null)
                      _StatusChip(
                        label: 'Seen ${_relativeTime(user.lastSeenAt!)}',
                        background: const Color(0xFFEFF6FF),
                        foreground: const Color(0xFF355C9A),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onChallenge,
            style: FilledButton.styleFrom(
              backgroundColor: selected
                  ? const Color(0xFFE0ECFF)
                  : AppColors.deepPurple,
              foregroundColor: selected ? AppColors.heading : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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

String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
