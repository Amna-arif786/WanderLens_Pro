import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/wishlist_service.dart';
import 'package:wanderlens/services/like_service.dart';
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

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkInteractionStatus();
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

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)));
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(post: widget.post, currentUserId: widget.currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.post.userId).snapshots(),
      builder: (context, snapshot) {
        User? author;
        if (snapshot.hasData && snapshot.data!.exists) {
          author = User.fromJson(snapshot.data!.data() as Map<String, dynamic>);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // Dark mode mein surfaceContainer (soft black) aur light mein pure white
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(isDark ? 0.2 : 0.5),
            ),
            boxShadow: [
              if (!isDark) // Shadows sirf light mode mein acchi lagti hain
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 5)
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(context, widget.post.userId),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 2)
                        ),
                        child: UserAvatar(imageUrl: author?.profileImageUrl ?? widget.post.userProfileImage, size: 38),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToProfile(context, widget.post.userId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                author?.displayName ?? widget.post.userDisplayName ?? 'User',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: colorScheme.onSurface // Black in light, White in dark
                                )
                            ),
                            Row(
                              children: [
                                Icon(Icons.place, size: 12, color: colorScheme.primary),
                                const SizedBox(width: 2),
                                Text(
                                    '${widget.post.location}, ${widget.post.cityName}',
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '• ${_getTimeAgo(widget.post.createdAt)}',
                                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7))
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Image Section
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post, currentUserId: widget.currentUserId))
                ),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 450, minHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      widget.post.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover, // Use cover for professional feed look
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : colorScheme.onSurface
                      ),
                      onPressed: () async {
                        setState(() => _isLiked = !_isLiked);
                        await LikeService.toggleLike(widget.post.id, widget.currentUserId);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.mode_comment_outlined, color: colorScheme.onSurface),
                      onPressed: _showComments,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSaved ? colorScheme.primary : colorScheme.onSurface
                      ),
                      onPressed: () async {
                        setState(() => _isSaved = !_isSaved);
                        await WishlistService.toggleWishlist(widget.post.id, widget.currentUserId);
                        widget.onPostUpdated?.call();
                      },
                    ),
                  ],
                ),
              ),

              // Caption & Likes Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.post.likeCount} likes',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colorScheme.onSurface
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () => _navigateToProfile(context, widget.post.userId),
                              child: Text(
                                  '${author?.username ?? widget.post.username}  ',
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                          TextSpan(text: widget.post.caption),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showComments,
                      child: Text(
                        'View all comments',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
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
  }
}