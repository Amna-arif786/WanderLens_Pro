import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/notification_model.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/wishlist_service.dart';
import 'package:wanderlens/services/like_service.dart';
import 'package:wanderlens/services/notification_service.dart';
import 'package:wanderlens/screens/post/post_detail_screen.dart';
import 'package:wanderlens/screens/profile/profile_screen.dart';
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

class _PostCardState extends State<PostCard> {
  User? _currentUser;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _currentUser = await UserService.getCurrentUser();
    final isSaved = await WishlistService.isPostInWishlist(widget.post.id, widget.currentUserId);
    if (mounted) setState(() => _isSaved = isSaved);
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
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(widget.post.id).snapshots(),
      builder: (context, postSnap) {
        if (!postSnap.hasData) return const SizedBox.shrink();
        
        final postData = postSnap.data!.data() as Map<String, dynamic>;
        final int likeCount = postData['likeCount'] ?? 0;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.post.id)
              .collection('likes')
              .doc(widget.currentUserId)
              .snapshots(),
          builder: (context, likeSnap) {
            final bool isLiked = likeSnap.hasData && likeSnap.data!.exists;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colorScheme),
                  
                  // Caption Header ke nichay aur Image ke upar (Bold)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      widget.post.caption,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),

                  _buildFeedImage(context, colorScheme),

                  _buildActions(isLiked, colorScheme),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$likeCount likes', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showComments,
                          child: Text(
                            'View all comments', 
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeedImage(BuildContext context, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            post: widget.post,
            currentUserId: widget.currentUserId,
          ),
        ),
      ),
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: Image.network(
          widget.post.imageUrl,
          width: double.infinity,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool isLiked, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : colorScheme.onSurface, size: 28),
            onPressed: () => _handleLike(isLiked),
          ),
          IconButton(
            icon: Icon(Icons.mode_comment_outlined, color: colorScheme.onSurface, size: 26),
            onPressed: _showComments,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? colorScheme.primary : colorScheme.onSurface, size: 28),
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(bool isLiked) async {
    await LikeService.toggleLike(widget.post.id, widget.currentUserId);
    if (!isLiked && _currentUser != null) {
      await NotificationService.createNotification(
        receiverId: widget.post.userId,
        sender: _currentUser!,
        type: NotificationType.like,
        postId: widget.post.id,
      );
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaved = !_isSaved);
    await WishlistService.toggleWishlist(widget.post.id, widget.currentUserId);
    widget.onPostUpdated?.call();
    if (_isSaved && _currentUser != null) {
      await NotificationService.createNotification(
        receiverId: widget.post.userId,
        sender: _currentUser!,
        type: NotificationType.wishlist,
        postId: widget.post.id,
      );
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(post: widget.post, currentUserId: widget.currentUserId),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return FutureBuilder<User?>(
      future: UserService.getUserById(widget.post.userId),
      builder: (context, snapshot) {
        final author = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.post.userId))),
                child: UserAvatar(imageUrl: author?.profileImageUrl ?? widget.post.userProfileImage, size: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.displayName ?? widget.post.userDisplayName ?? 'User', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)
                    ),
                    Text(
                      '${widget.post.cityName} • ${_getTimeAgo(widget.post.createdAt)}', 
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)
                    ),
                  ],
                ),
              ),
              // More_vert icon hata diya gaya hai kyunki abhi koi options nahi hain
            ],
          ),
        );
      },
    );
  }
}
