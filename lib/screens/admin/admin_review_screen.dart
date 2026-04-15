import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/responsive/constrained_scaffold.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  List<Post> _pendingPosts = [];
  bool _loading = true;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    final posts = await PostService.getPendingPosts();
    if (mounted) {
      setState(() {
        _pendingPosts = posts;
        _loading = false;
      });
    }
  }

  Future<void> _approve(Post post) async {
    setState(() => _processing.add(post.id));
    try {
      await PostService.approvePost(post.id);
      if (mounted) {
        setState(() => _pendingPosts.removeWhere((p) => p.id == post.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post approved — now visible in feed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approve failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(post.id));
    }
  }

  Future<void> _confirmReject(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Post?'),
        content: const Text(
          'This will permanently delete the image from Cloudinary and '
          'mark the post as rejected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject & Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _processing.add(post.id));
    try {
      await PostService.rejectPost(post.id);
      if (mounted) {
        setState(() => _pendingPosts.removeWhere((p) => p.id == post.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post rejected and image deleted from Cloudinary.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Admin Review',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_pendingPosts.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingPosts.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPending,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingPosts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) =>
                        _PendingPostCard(
                      post: _pendingPosts[i],
                      isProcessing: _processing.contains(_pendingPosts[i].id),
                      onApprove: () => _approve(_pendingPosts[i]),
                      onReject: () => _confirmReject(_pendingPosts[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 72,
              color: Colors.green.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          const Text('No Pending Posts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'All posts have been reviewed.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PendingPostCard extends StatelessWidget {
  const _PendingPostCard({
    required this.post,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final Post post;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ──────────────────────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: post.imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 40),
              ),
            ),
          ),

          // ── Meta ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + time
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '@${post.username ?? 'unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(post.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${post.location} · ${post.cityName}',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Caption
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),

                // Status badge
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 13, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Pending Review',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                ),

                // ── AI Metadata ───────────────────────────────────────────────
                const SizedBox(height: 10),
                _AiMetaBadges(post: post),

                // ── Action buttons ────────────────────────────────────────────
                const SizedBox(height: 14),
                isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          // Reject
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onReject,
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              label: const Text('Reject',
                                  style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Approve
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: onApprove,
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── AI metadata badges ────────────────────────────────────────────────────────

class _AiMetaBadges extends StatelessWidget {
  const _AiMetaBadges({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final confidence = post.aiConfidenceScore;
    final labels = post.aiDetectedLabels;
    final source = post.aiVerificationSource;

    if (confidence == 0.0 && labels.isEmpty && source == 'none') {
      return const SizedBox.shrink();
    }

    final sourceIcon = switch (source) {
      'mlKit' => Icons.phone_android,
      'cloudinaryAI' => Icons.cloud_outlined,
      'cloudVision' => Icons.visibility_outlined,
      _ => Icons.smart_toy_outlined,
    };
    final sourceLabel = switch (source) {
      'mlKit' => 'ML Kit',
      'cloudinaryAI' => 'Cloudinary AI',
      'cloudVision' => 'Cloud Vision',
      _ => 'Unknown',
    };

    // Confidence colour: green ≥ 70%, orange ≥ 45%, red < 45%
    final confColor = confidence >= 0.70
        ? Colors.green
        : confidence >= 0.45
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source + confidence row
        Row(
          children: [
            // AI source chip
            _Chip(
              icon: sourceIcon,
              label: sourceLabel,
              color: Colors.blue,
            ),
            const SizedBox(width: 6),
            // Confidence chip
            if (confidence > 0)
              _Chip(
                icon: Icons.bar_chart,
                label: '${(confidence * 100).toStringAsFixed(0)}% conf.',
                color: confColor,
              ),
          ],
        ),
        // Detected labels
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: labels
                .take(5)
                .map((l) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
