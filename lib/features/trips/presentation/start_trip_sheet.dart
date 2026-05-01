import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/trips/application/trip_controller.dart';
import 'package:fishing_with_friends/features/trips/domain/trip.dart';
import 'package:fishing_with_friends/features/trips/domain/trip_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartTripSheet extends ConsumerStatefulWidget {
  const StartTripSheet({super.key});

  @override
  ConsumerState<StartTripSheet> createState() => _StartTripSheetState();

  /// Convenience opener — returns the freshly-started Trip on success.
  static Future<Trip?> show(BuildContext context) {
    return showModalBottomSheet<Trip?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StartTripSheet(),
    );
  }
}

class _StartTripSheetState extends ConsumerState<StartTripSheet> {
  final _titleCtl = TextEditingController();
  final _waterCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtl.dispose();
    _waterCtl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    final trip = await ref.read(tripControllerProvider.notifier).start(
          TripInput(
            title: _titleCtl.text.trim(),
            bodyOfWater: _waterCtl.text.trim().isEmpty
                ? null
                : _waterCtl.text.trim(),
          ),
        );
    if (!mounted) return;

    if (trip != null) {
      Navigator.of(context).pop(trip);
      return;
    }
    final err = ref.read(tripControllerProvider).error;
    if (err is AppException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(tripControllerProvider).isLoading;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Start a trip',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Catches you log will join this trip until you end it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _titleCtl,
                  decoration: const InputDecoration(
                    labelText: 'Trip title',
                    hintText: 'Saturday at Lake Erie',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _waterCtl,
                  decoration: const InputDecoration(
                    labelText: 'Body of water (optional)',
                    hintText: 'Lake Erie',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: busy ? null : _start,
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
                      : const Icon(Icons.play_arrow),
                  label: Text(busy ? 'Starting…' : 'Start trip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
