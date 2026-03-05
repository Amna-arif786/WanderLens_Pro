import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/wishlist_service.dart';
import 'package:wanderlens/services/like_service.dart';
import 'package:wanderlens/screens/post/post_detail_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import 'package:wanderlens/widgets/comments_bottom_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback? onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _isSaved = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _checkInteractionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkInteractionStatus() async {
    final isLiked = await LikeService.isPostLikedByUser(widget.post.id, widget.currentUserId);
    final isSaved = await WishlistService.isPostInWishlist(widget.post.id, widget.currentUserId);
    if (mounted) {
      setState(() {
        _isLiked = isLiked;
        _isSaved = isSaved;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 7) return DateFormat('MMM d').format(dateTime);
    if (duration.inDays >= 1) return '${duration.inDays}d ago';
    if (duration.inHours >= 1) return '${duration.inHours}h ago';
    if (duration.inMinutes >= 1) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    // Stream user data to ensure profile picture is always the latest
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.post.userId).snapshots(),
      builder: (context, snapshot) {
        User? author;
        if (snapshot.hasData && snapshot.data!.exists) {
          author = User.fromJson(snapshot.data!.data() as Map<String, dynamic>);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    UserAvatar(imageUrl: author?.profileImageUrl ?? widget.post.userProfileImage, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(author?.displayName ?? widget.post.userDisplayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('• ${_getTimeAgo(widget.post.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                          Text('📍 ${widget.post.location}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Post Image
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post, currentUserId: widget.currentUserId))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 500),
                    width: double.infinity,
                    child: Image.network(widget.post.imageUrl, width: double.infinity, fit: BoxFit.contain),
                  ),
                ),
              ),
              // Action Buttons (Like, Comment, Save)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : null),
                      onPressed: () async {
                        setState(() => _isLiked = !_isLiked);
                        await LikeService.toggleLike(widget.post.id, widget.currentUserId);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? Colors.blue : null),
                      onPressed: () async {
                        setState(() => _isSaved = !_isSaved);
                        await WishlistService.toggleWishlist(widget.post.id, widget.currentUserId);
                        widget.onPostUpdated?.call();
                      },
                    ),
                  ],
                ),
              ),
              // Caption
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    children: [
                      TextSpan(text: '${author?.username ?? widget.post.username} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: widget.post.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
