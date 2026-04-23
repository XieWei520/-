import 'package:flutter/material.dart';

import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import 'moments_service.dart';

class MomentDetailPage extends StatefulWidget {
  final String momentId;

  const MomentDetailPage({super.key, required this.momentId});

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends State<MomentDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final MomentsService _service = MomentsService.instance;

  Moment? _moment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMoment();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadMoment() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final moment = await _service.getMomentDetail(widget.momentId);
      if (!mounted) {
        return;
      }
      setState(() => _moment = moment);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _moment = null);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_moment == null) {
      return;
    }

    try {
      if (_moment!.isLiked) {
        await _service.unlikeMoment(widget.momentId);
      } else {
        await _service.likeMoment(widget.momentId);
      }
      await _loadMoment();
    } catch (error) {
      _showSnackBar('操作失败: $error', isError: true);
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      await _service.commentMoment(momentId: widget.momentId, content: content);
      _commentController.clear();
      if (!mounted) {
        return;
      }
      FocusScope.of(context).unfocus();
      await _loadMoment();
    } catch (error) {
      _showSnackBar('评论失败: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('动态详情')),
        body: const WKLoadingView(message: '正在加载详情…'),
      );
    }

    if (_moment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('动态详情')),
        body: WKErrorView(
          message: '动态加载失败',
          subMessage: '请稍后重试',
          onRetry: _loadMoment,
        ),
      );
    }

    final moment = _moment!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('动态详情')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMoment,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.xl,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(WKSpace.lg),
                    decoration: BoxDecoration(
                      color: WKColors.surface,
                      borderRadius: BorderRadius.circular(WKRadius.xl),
                      border: Border.all(color: WKColors.outline),
                      boxShadow: WKShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            WKAvatar(
                              url: moment.avatar,
                              name: moment.username,
                              size: 46,
                            ),
                            const SizedBox(width: WKSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    moment.username,
                                    style: textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTime(moment.createdAt),
                                    style: textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((moment.content ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: WKSpace.md),
                          Text(
                            moment.content!.trim(),
                            style: textTheme.bodyLarge,
                          ),
                        ],
                        if ((moment.location ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: WKSpace.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: WKColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  moment.location!,
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (moment.mentions.isNotEmpty) ...[
                          const SizedBox(height: WKSpace.sm),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: moment.mentions
                                .map((item) => Chip(label: Text('@$item')))
                                .toList(growable: false),
                          ),
                        ],
                        if (moment.images.isNotEmpty) ...[
                          const SizedBox(height: WKSpace.md),
                          _MomentImageGrid(images: moment.images),
                        ],
                        const SizedBox(height: WKSpace.md),
                        Row(
                          children: [
                            _ActionChip(
                              icon: moment.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              label: '${moment.likeCount}',
                              active: moment.isLiked,
                              onTap: _toggleLike,
                            ),
                            const SizedBox(width: WKSpace.sm),
                            _ActionChip(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '${moment.commentCount}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (moment.likes.isNotEmpty) ...[
                    const SizedBox(height: WKSpace.md),
                    _SectionCard(
                      title: '点赞',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: moment.likes
                            .map(
                              (like) => Chip(
                                label: Text(like.username),
                                avatar: WKAvatar(
                                  url: like.avatar,
                                  name: like.username,
                                  size: 24,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: WKSpace.md),
                  _SectionCard(
                    title: '评论',
                    child: moment.comments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: WKSpace.xs),
                            child: Text('还没有评论，抢个沙发吧。'),
                          )
                        : Column(
                            children: moment.comments
                                .map(
                                  (comment) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: WKSpace.md,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        WKAvatar(
                                          url: comment.avatar,
                                          name: comment.username,
                                          size: 36,
                                        ),
                                        const SizedBox(width: WKSpace.sm),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(
                                              WKSpace.md,
                                            ),
                                            decoration: BoxDecoration(
                                              color: WKColors.surfaceSoft,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    WKRadius.lg,
                                                  ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  comment.username,
                                                  style: textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                if (comment.replyUsername !=
                                                    null)
                                                  Text(
                                                    '回复 @${comment.replyUsername}',
                                                    style: textTheme.labelSmall,
                                                  ),
                                                Text(comment.content),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _formatTime(
                                                    comment.createdAt,
                                                  ),
                                                  style: textTheme.labelSmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              WKSpace.md,
              WKSpace.sm,
              WKSpace.md,
              WKSpace.sm + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: WKColors.surface,
              border: Border(top: BorderSide(color: WKColors.outline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: '写下你的评论…'),
                  ),
                ),
                const SizedBox(width: WKSpace.sm),
                IconButton(
                  onPressed: _sendComment,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}Сʱǰ';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    }
    return '刚刚';
  }
}

class _MomentImageGrid extends StatelessWidget {
  final List<String> images;

  const _MomentImageGrid({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(WKRadius.lg),
        child: Image.network(
          images.first,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }

    final crossAxisCount = images.length == 2 || images.length == 4 ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.sm),
          child: Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: WKColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        border: Border.all(color: WKColors.outline),
        boxShadow: WKShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: WKSpace.sm),
          child,
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? WKColors.brand500 : WKColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(WKRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WKSpace.sm,
          vertical: WKSpace.xs,
        ),
        decoration: BoxDecoration(
          color: active ? WKColors.brand50 : WKColors.surfaceSoft,
          borderRadius: BorderRadius.circular(WKRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
