import 'dart:async';

import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournaments_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Modal bottom sheet for entering an 8-character tournament join code.
/// Wires to TournamentsRepository.requestJoinByCode — on success, pops
/// the sheet and routes to the tournament detail screen as a pending
/// member (cold-invite path; the creator must approve).
class JoinByCodeSheet extends ConsumerStatefulWidget {
  const JoinByCodeSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const JoinByCodeSheet._(),
    );
  }

  @override
  ConsumerState<JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends ConsumerState<JoinByCodeSheet> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _ctl.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Code must be 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw const AuthFailure('Sign in to join a tournament.');
      }
      final tournament = await ref
          .read(tournamentsRepositoryProvider)
          .requestJoinByCode(code: code, anglerId: user.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      // Route to the tournament detail screen so the user immediately
      // sees the place they just joined.
      unawaited(context.push('/tournaments/${tournament.id}'));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Enter join code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Paste the 8-character code the tournament creator '
                'shared with you.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _ctl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  // Uppercase + alphanumeric only, max 8 chars. Mirrors
                  // the on-screen styling of the join code in the
                  // creator's Members tab.
                  FilteringTextInputFormatter.allow(
                    RegExp('[A-Za-z0-9]'),
                  ),
                  LengthLimitingTextInputFormatter(8),
                  TextInputFormatter.withFunction(
                    (old, fresh) => fresh.copyWith(
                      text: fresh.text.toUpperCase(),
                    ),
                  ),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
                decoration: const InputDecoration(
                  hintText: 'XXXX-XXXX',
                ),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                        ),
                      )
                    : const Text('Join tournament'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
