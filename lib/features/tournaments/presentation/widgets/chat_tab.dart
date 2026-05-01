import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/core/supabase/supabase_providers.dart';
import 'package:fishing_with_friends/core/theme/app_spacing.dart';
import 'package:fishing_with_friends/features/feed/presentation/widgets/comment_body_text.dart';
import 'package:fishing_with_friends/features/friends/data/friends_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_chat_repository_provider.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChatTab extends ConsumerWidget {
  const ChatTab({required this.tournamentId, super.key});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMessages =
        ref.watch(tournamentChatProvider(tournamentId));
    return Column(
      children: [
        Expanded(
          child: asyncMessages.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Be the first to say something.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: messages.length,
                itemBuilder: (_, i) =>
                    _MessageRow(message: messages[i]),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text("Couldn't load chat."),
            ),
          ),
        ),
        const Divider(height: 1),
        _Composer(tournamentId: tournamentId),
      ],
    );
  }
}

class _MessageRow extends ConsumerWidget {
  const _MessageRow({required this.message});

  final TournamentChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(friendsBundleProvider).valueOrNull;
    final author = bundle?.profilesById[message.authorId];
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Icon(Icons.person,
                size: 16, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author?.handle ?? '@angler',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      DateFormat.MMMd()
                          .add_jm()
                          .format(message.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (message.isDeleted)
                  Text(
                    '[deleted]',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                  )
                else
                  CommentBodyText(message.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _ctl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _ctl.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await ref.read(tournamentChatRepositoryProvider).post(
            tournamentId: widget.tournamentId,
            authorId: user.id,
            body: body,
          );
      _ctl.clear();
      ref.invalidate(tournamentChatProvider(widget.tournamentId));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Trash talk welcome...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: _busy ? null : _send,
            icon: _busy
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
