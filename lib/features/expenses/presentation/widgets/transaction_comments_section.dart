import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class TransactionCommentsSection extends ConsumerStatefulWidget {
  final String expenseId;
  final String cohortId;

  const TransactionCommentsSection({
    super.key,
    required this.expenseId,
    required this.cohortId,
  });

  @override
  ConsumerState<TransactionCommentsSection> createState() =>
      _TransactionCommentsSectionState();
}

class _TransactionCommentsSectionState
    extends ConsumerState<TransactionCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _tagQuery = '';
  bool _showTagSuggestions = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleTextChange);
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _commentController.text;
    final lastAtIndex = text.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final query = text.substring(lastAtIndex + 1).toLowerCase();
      if (!query.contains(' ')) {
        setState(() {
          _tagQuery = query;
          _showTagSuggestions = true;
        });
        return;
      }
    }

    if (_showTagSuggestions) {
      setState(() {
        _showTagSuggestions = false;
        _tagQuery = '';
      });
    }
  }

  void _handleSelectMention(String handle) {
    final text = _commentController.text;
    final lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex != -1) {
      final beforeAt = text.substring(0, lastAtIndex);
      final newText = '$beforeAt@$handle ';
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    setState(() {
      _showTagSuggestions = false;
      _tagQuery = '';
    });
  }

  Future<void> _handleSubmit() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    setState(() {
      _showTagSuggestions = false;
      _tagQuery = '';
    });

    try {
      await ref
          .read(expenseCommentsProvider(widget.expenseId).notifier)
          .addComment(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  List<InlineSpan> _buildFormattedText(
      String content, AppThemeColors colors) {
    final spans = <InlineSpan>[];
    final regExp = RegExp(r'(@[a-zA-Z0-9_]+)');
    final matches = regExp.allMatches(content);

    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: TextStyle(
            fontSize: 13,
            color: colors.textMain,
            height: 1.4,
          ),
        ));
      }

      final tag = match.group(0)!;
      spans.add(TextSpan(
        text: tag,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: colors.cyan,
          height: 1.4,
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: TextStyle(
          fontSize: 13,
          color: colors.textMain,
          height: 1.4,
        ),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final commentsAsync =
        ref.watch(expenseCommentsProvider(widget.expenseId));
    final comments = commentsAsync.value ?? [];
    final members = ref.watch(groupMembersProvider(widget.cohortId));
    final currentUser = ref.watch(currentUserProvider);

    // Filter members matching the @ tag query
    final matchingMembers = members.where((m) {
      final name = m.profile?.displayName.toLowerCase() ?? '';
      final username = m.profile?.username?.toLowerCase() ?? '';
      return name.contains(_tagQuery) || username.contains(_tagQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DISCUSSION & NOTES (${comments.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
            if (comments.isNotEmpty)
              Text(
                'Live Audit',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.cyan,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Comments List Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.accentPill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No comments yet. Start a discussion or tag friends with @username or @all.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 16, color: colors.border),
                  itemBuilder: (context, idx) {
                    final comment = comments[idx];
                    final isMe = currentUser != null &&
                        comment.userId == currentUser.id;
                    final member = members
                        .where((m) => m.userId == comment.userId)
                        .firstOrNull;
                    final name = isMe
                        ? 'You'
                        : (member?.profile?.displayName ??
                            comment.profile?.displayName ??
                            'User');

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Initial
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: colors.surface,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.cyan,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Comment Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textMain,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTimeAgo(comment.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  children: _buildFormattedText(
                                      comment.content, colors),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 14),

              // Tag Suggestions Bar
              if (_showTagSuggestions) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // @all chip
                      if ('all'.contains(_tagQuery) ||
                          'everyone'.contains(_tagQuery) ||
                          _tagQuery.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 8),
                          child: ActionChip(
                            avatar: Icon(Icons.people_alt_rounded,
                                size: 14, color: colors.cyan),
                            label: const Text('@all'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colors.cyan,
                            ),
                            backgroundColor: colors.surface,
                            side: BorderSide(color: colors.cyan),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onPressed: () => _handleSelectMention('all'),
                          ),
                        ),

                      // Member chips
                      ...matchingMembers.map((m) {
                        final handle = m.profile?.username ??
                            m.profile?.displayName
                                .toLowerCase()
                                .replaceAll(' ', '_') ??
                            'user';
                        final displayName = m.profile?.displayName ?? 'Member';

                        return Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 8),
                          child: ActionChip(
                            label: Text('@$displayName'),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.textMain,
                            ),
                            backgroundColor: colors.surface,
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onPressed: () => _handleSelectMention(handle),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // Input Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMain,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a comment or tag @...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _handleSubmit(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleSubmit,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.cyan,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Color(0xFF0D131A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
