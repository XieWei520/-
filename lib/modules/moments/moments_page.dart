import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/media_cache_manager.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import 'moment_detail_page.dart';
import 'moments_service.dart';
import 'publish_moment_page.dart';

class MomentsPage extends ConsumerStatefulWidget {
  const MomentsPage({super.key});

  @override
  ConsumerState<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends ConsumerState<MomentsPage> {
  final MomentsService _service = MomentsService.instance;
  List<Moment> _moments = <Moment>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  Future<void> _loadMoments() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final moments = await _service.getMoments();
      if (!mounted) {
        return;
      }
      setState(() => _moments = moments);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _moments = <Moment>[]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPublishPage() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PublishMomentPage()),
    );

    if (result != null) {
      await _loadMoments();
    }
  }

  Future<void> _toggleLike(Moment moment) async {
    try {
      if (moment.isLiked) {
        await _service.unlikeMoment(moment.id);
      } else {
        await _service.likeMoment(moment.id);
      }
      await _loadMoments();
    } catch (error) {
      _showSnackBar('操作失败: $error', isError: true);
    }
  }

  Future<void> _deleteMoment(Moment moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除动态'),
          content: const Text('删除后将无法恢复，确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteMoment(moment.id);
      await _loadMoments();
      _showSnackBar('动态已删除');
    } catch (error) {
      _showSnackBar('删除失败: $error', isError: true);
    }
  }

  Future<void> _openMomentDetail(Moment moment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MomentDetailPage(momentId: moment.id)),
    );
    await _loadMoments();
  }

  Future<void> _openSearch() async {
    if (_moments.isEmpty) {
      _showSnackBar('暂无可搜索的朋友圈内容');
      return;
    }

    final selected = await showSearch<Moment?>(
      context: context,
      delegate: _MomentSearchDelegate(_moments),
    );

    if (!mounted || selected == null) {
      return;
    }
    await _openMomentDetail(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朋友圈'),
        actions: [
          IconButton(
            tooltip: '搜索动态',
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: '发布动态',
            onPressed: _openPublishPage,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const WKLoadingView(message: '正在加载动态...')
          : _moments.isEmpty
          ? WKEmptyView(
              icon: Icons.photo_library_outlined,
              message: '还没有朋友圈内容',
              subMessage: '发布第一条动态，建立统一、精致的内容展示体验。',
              onRefresh: _openPublishPage,
            )
          : RefreshIndicator(
              onRefresh: _loadMoments,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.xl,
                ),
                itemCount: _moments.length,
                separatorBuilder: (_, _) => const SizedBox(height: WKSpace.md),
                itemBuilder: (context, index) {
                  final moment = _moments[index];
                  return _MomentCard(
                    moment: moment,
                    onTap: () => _openMomentDetail(moment),
                    onLike: () => _toggleLike(moment),
                    onComment: () => _openMomentDetail(moment),
                    onDelete: () => _deleteMoment(moment),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPublishPage,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('发布'),
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
}

class _MomentCard extends StatelessWidget {
  final Moment moment;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _MomentCard({
    required this.moment,
    required this.onTap,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(WKRadius.xl),
        onTap: onTap,
        child: Ink(
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
                  WKAvatar(url: moment.avatar, name: moment.username, size: 44),
                  const SizedBox(width: WKSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(moment.username, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(moment.createdAt),
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(
                          '删除',
                          style: TextStyle(color: WKColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if ((moment.content ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: WKSpace.md),
                Text(moment.content!.trim(), style: textTheme.bodyLarge),
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
                      child: Text(moment.location!, style: textTheme.bodySmall),
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
                _MomentImages(images: moment.images),
              ],
              const SizedBox(height: WKSpace.md),
              Row(
                children: [
                  _MomentAction(
                    icon: moment.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '${moment.likeCount}',
                    active: moment.isLiked,
                    onTap: onLike,
                  ),
                  const SizedBox(width: WKSpace.md),
                  _MomentAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${moment.commentCount}',
                    onTap: onComment,
                  ),
                ],
              ),
              if (moment.likes.isNotEmpty) ...[
                const SizedBox(height: WKSpace.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(WKSpace.sm),
                  decoration: BoxDecoration(
                    color: WKColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(WKRadius.lg),
                  ),
                  child: Text(
                    '点赞 · ${moment.likes.map((item) => item.username).join('、')}',
                    style: textTheme.bodySmall?.copyWith(
                      color: WKColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _MomentImages extends StatelessWidget {
  final List<String> images;

  const _MomentImages({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final decodeSize = _resolveMomentDecodeBound(
        220,
        MediaQuery.devicePixelRatioOf(context),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(WKRadius.lg),
        child: CachedMediaImage(
          imageUrl: images.first,
          cacheKey: images.first,
          width: 220,
          height: 220,
          maxWidth: decodeSize,
          maxHeight: decodeSize,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(220, 220),
          errorWidget: (_, _, _) => _fallback(220, 220),
        ),
      );
    }

    final crossAxisCount = images.length == 2 || images.length == 4 ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length > 9 ? 9 : images.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
              return CachedMediaImage(
                imageUrl: images[index],
                cacheKey: images[index],
                maxWidth: _resolveMomentDecodeBound(
                  constraints.maxWidth,
                  devicePixelRatio,
                ),
                maxHeight: _resolveMomentDecodeBound(
                  constraints.maxHeight,
                  devicePixelRatio,
                ),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    _fallback(double.infinity, double.infinity),
                errorWidget: (_, _, _) =>
                    _fallback(double.infinity, double.infinity),
              );
            },
          ),
        );
      },
    );
  }

  Widget _fallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: WKColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: WKColors.textTertiary,
      ),
    );
  }
}

int? _resolveMomentDecodeBound(double logicalSize, double devicePixelRatio) {
  if (!logicalSize.isFinite || logicalSize <= 0 || devicePixelRatio <= 0) {
    return null;
  }
  return (logicalSize * devicePixelRatio).ceil();
}

class _MomentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _MomentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? WKColors.brand500 : WKColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(WKRadius.pill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WKSpace.sm,
          vertical: WKSpace.xs,
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

class _MomentSearchDelegate extends SearchDelegate<Moment?> {
  _MomentSearchDelegate(this.moments);

  final List<Moment> moments;

  @override
  String get searchFieldLabel => '搜索朋友圈';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.trim().isNotEmpty)
        IconButton(
          tooltip: '清空',
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return const _MomentSearchPlaceholder(
        icon: Icons.travel_explore_rounded,
        title: '搜索朋友圈内容',
        subtitle: '支持搜索作者、正文、评论和点赞用户',
      );
    }

    final results = moments
        .where((moment) => _matches(moment, keyword))
        .toList(growable: false);

    if (results.isEmpty) {
      return const _MomentSearchPlaceholder(
        icon: Icons.search_off_rounded,
        title: '没有找到相关动态',
        subtitle: '可以换个关键词试试',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        WKSpace.md,
        WKSpace.md,
        WKSpace.md,
        WKSpace.xl,
      ),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: WKSpace.sm),
      itemBuilder: (context, index) {
        final moment = results[index];
        final subtitle = _subtitle(moment);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WKRadius.lg),
            onTap: () => close(context, moment),
            child: Ink(
              padding: const EdgeInsets.all(WKSpace.md),
              decoration: BoxDecoration(
                color: WKColors.surface,
                borderRadius: BorderRadius.circular(WKRadius.lg),
                border: Border.all(color: WKColors.outline),
              ),
              child: Row(
                children: [
                  WKAvatar(url: moment.avatar, name: moment.username, size: 44),
                  const SizedBox(width: WKSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moment.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: WKSpace.sm),
                  Text(
                    _formatTime(moment.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _matches(Moment moment, String keyword) {
    final fields = <String>[
      moment.username,
      moment.uid,
      moment.content ?? '',
      ...moment.comments.expand(
        (comment) => <String>[
          comment.username,
          comment.replyUsername ?? '',
          comment.content,
        ],
      ),
      ...moment.likes.map((like) => like.username),
    ];

    return fields.any((field) => field.toLowerCase().contains(keyword));
  }

  String _subtitle(Moment moment) {
    final content = (moment.content ?? '').trim();
    if (content.isNotEmpty) {
      return content;
    }
    if (moment.images.isNotEmpty) {
      return '图片动态 · ${moment.images.length} 张图片';
    }
    return '${moment.username} 发布的动态';
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}

class _MomentSearchPlaceholder extends StatelessWidget {
  const _MomentSearchPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WKSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: WKColors.textTertiary),
            const SizedBox(height: WKSpace.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: WKSpace.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
