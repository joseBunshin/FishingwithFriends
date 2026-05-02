import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/tournaments/application/tournament_create_controller.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CreateTournamentSheet extends ConsumerStatefulWidget {
  const CreateTournamentSheet({super.key});

  static Future<Tournament?> show(BuildContext context) {
    return showModalBottomSheet<Tournament?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateTournamentSheet(),
    );
  }

  @override
  ConsumerState<CreateTournamentSheet> createState() =>
      _CreateTournamentSheetState();
}

class _CreateTournamentSheetState
    extends ConsumerState<CreateTournamentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  TournamentMetric _metric = TournamentMetric.weight;
  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(hours: 8));

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool forStart}) async {
    final initial = forStart ? _starts : _ends;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      final dt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      if (forStart) {
        _starts = dt;
        if (!_ends.isAfter(_starts)) {
          _ends = _starts.add(const Duration(hours: 8));
        }
      } else {
        _ends = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_ends.isAfter(_starts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End must be after start.')),
      );
      return;
    }
    final input = TournamentInput(
      name: _nameCtl.text.trim(),
      description: _descCtl.text.trim().isEmpty
          ? null
          : _descCtl.text.trim(),
      metric: _metric,
      startsAt: _starts.toUtc(),
      endsAt: _ends.toUtc(),
    );
    final tournament = await ref
        .read(tournamentCreateControllerProvider.notifier)
        .submit(input);
    if (!mounted) return;
    if (tournament != null) {
      Navigator.of(context).pop(tournament);
      await context.push('/tournaments/${tournament.id}');
      return;
    }
    final err = ref.read(tournamentCreateControllerProvider).error;
    if (err is AppException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(tournamentCreateControllerProvider).isLoading;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Tournament',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Tournament Name *',
                    hintText: 'Bass Brawl 2026',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descCtl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Rules, details...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Start *',
                        text: DateFormat.yMd().add_jm().format(_starts),
                        onTap: () => _pickDate(forStart: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _DateField(
                        label: 'End *',
                        text: DateFormat.yMd().add_jm().format(_ends),
                        onTap: () => _pickDate(forStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<TournamentMetric>(
                  initialValue: _metric,
                  decoration: const InputDecoration(
                    labelText: 'Scoring Method *',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TournamentMetric.weight,
                      child: Text('Total Weight'),
                    ),
                    DropdownMenuItem(
                      value: TournamentMetric.length,
                      child: Text('Total Length'),
                    ),
                    DropdownMenuItem(
                      value: TournamentMetric.biggestFish,
                      child: Text('Biggest Fish'),
                    ),
                    DropdownMenuItem(
                      value: TournamentMetric.mostCatches,
                      child: Text('Most Catches'),
                    ),
                    DropdownMenuItem(
                      value: TournamentMetric.longestCatch,
                      child: Text('Longest Catch'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _metric = v ?? _metric),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.emoji_events_outlined),
                  label: Text(busy ? 'Creating…' : 'Create Tournament'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.text,
    required this.onTap,
  });

  final String label;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(text),
      ),
    );
  }
}
