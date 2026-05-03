import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/feed/application/comment_controller.dart';
import 'package:fishing_with_friends/features/feed/data/feed_writers_provider.dart';
import 'package:fishing_with_friends/features/feed/domain/comment.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/comment_body_text.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/profile/presentation/widgets/avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CommentList extends ConsumerWidget {
  const CommentList({required this.catchId, super.key});

  final String catchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComments = ref.watch(catchCommentsProvider(catchId));
    return asyncComments.when(
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Be the first to comment.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in comments)
              _CommentRow(comment: c, catchId: catchId),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          "Couldn't load comments.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({required this.comment, required this.catchId});

  final Comment comment;
  final String catchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final author = bundle?.profilesById[comment.authorId];
    final isMine = comment.authorId == me?.id;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/profile/${comment.authorId}'),
            customBorder: const CircleBorder(),
            child: AvatarView(avatarPath: author?.avatarPath, radius: 14),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () =>
                          context.push('/profile/${comment.authorId}'),
                      child: Text(
                        author?.handle ?? (isMine ? '@you' : '@angler'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      DateFormat.MMMd()
                          .add_jm()
                          .format(comment.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (comment.isDeleted)
                  Text(
                    '[deleted]',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                  )
                else
                  CommentBodyText(comment.body),
              ],
            ),
          ),
          if (isMine && !comment.isDeleted)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
              tooltip: 'Delete',
              onPressed: () async {
                final ok = await _confirm(context);
                if (ok ?? false) {
                  await ref.read(commentControllerProvider.notifier).softDelete(
                        commentId: comment.id,
                        catchId: catchId,
                      );
                }
              },
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({required this.catchId, super.key});

  final String catchId;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    final result =
        await ref.read(commentControllerProvider.notifier).post(
              catchId: widget.catchId,
              body: body,
            );
    if (!mounted) return;
    if (result != null) {
      _controller.clear();
      return;
    }
    final err = ref.read(commentControllerProvider).error;
    if (err is AppException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(commentControllerProvider).isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: CommentsRepoMaxLength.value,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: busy ? null : _send,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// Small re-export so the composer doesn't drag the full repository import.
class CommentsRepoMaxLength {
  const CommentsRepoMaxLength._();
  static const int value = 2000;
}
