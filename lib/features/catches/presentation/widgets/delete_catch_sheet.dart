import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Long-press / overflow-menu entry point for deleting a catch the user
/// owns. Shows a destructive confirm sheet → calls the repository →
/// invalidates the catches providers → snackbar feedback. RLS prevents
/// non-owners from reaching this even if a stale UI offered it.
class DeleteCatchSheet {
  const DeleteCatchSheet._();

  /// Returns true when the catch was deleted, false when the user
  /// cancelled or the delete failed.
  static Future<bool> show(BuildContext context, {required Catch catch_}) {
    return showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => _Body(catch_: catch_),
        ).then((v) => v ?? false);
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.catch_});
  final Catch catch_;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;
  String? _error;

  String _subtitle() => widget.catch_.speciesLabel ?? 'No species labeled';

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(catchesRepositoryProvider).delete(widget.catch_.id);
      ref
        ..invalidate(myCatchesProvider)
        ..invalidate(syncedMyCatchesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${widget.catch_.speciesLabel ?? 'catch'}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: scheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete catch?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      _subtitle(),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This is permanent. Photos, conditions, and any tournament '
            'entries from this catch will be removed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: _busy ? null : _delete,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(_busy ? 'Deleting…' : 'Delete catch'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
