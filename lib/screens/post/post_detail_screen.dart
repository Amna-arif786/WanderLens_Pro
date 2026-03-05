import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/comment.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/comment_service.dart';
import 'package:wanderlens/services/like_service.dart';
import 'package:wanderlens/services/wishlist_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

import '../../responsive/constrained_scaffold.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback? onPostUpdated;
  final bool focusComment;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onPostUpdated,
    this.focusComment = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  User? _postAuthor;
  List<Comment> _comments = [];
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPostDetails();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final author = await UserService.getUserById(widget.post.userId);
      final comments = await CommentService.getCommentsByPostId(widget.post.id);
      final isLiked = await LikeService.isPostLikedByUser(widget.post.id, widget.currentUserId);
      final isSaved = await WishlistService.isPostInWishlist(widget.post.id, widget.currentUserId);

      if (mounted) {
        setState(() {
          _postAuthor = author;
          _comments = comments;
          _isLiked = isLiked;
          _isSaved = isSaved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId.isEmpty) return;
    setState(() => _isLiked = !_isLiked);
    try {
      await LikeService.toggleLike(widget.post.id, widget.currentUserId);
      widget.onPostUpdated?.call();
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) return;
    setState(() => _isSaved = !_isSaved);
    try {
      await WishlistService.toggleWishlist(widget.post.id, widget.currentUserId);
      widget.onPostUpdated?.call();
    } catch (e) {
      setState(() => _isSaved = !_isSaved);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSubmittingComment = true);
    try {
      await CommentService.createComment(
        postId: widget.post.id,
        userId: widget.currentUserId,
        content: _commentController.text.trim(),
      );
      _commentController.clear();
      _loadPostDetails();
      widget.onPostUpdated?.call();
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _showCommentOptions(Comment comment) {
    if (comment.userId != widget.currentUserId) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Comment'),
            onTap: () {
              Navigator.pop(context);
              _showEditCommentDialog(comment);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Comment', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await CommentService.deleteComment(widget.post.id, comment.id);
              _loadPostDetails();
            },
          ),
        ],
      ),
    );
  }

  void _showEditCommentDialog(Comment comment) {
    final controller = TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await CommentService.updateComment(widget.post.id, comment.id, controller.text);
              Navigator.pop(context);
              _loadPostDetails();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Post Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(0),
                    children: [
                      _buildPostHeader(),
                      _buildPostImage(),
                      _buildActionButtons(),
                      const Divider(),
                      _buildCommentsList(),
                    ],
                  ),
                ),
                _buildCommentInput(),
              ],
            ),
    );
  }

  Widget _buildPostHeader() {
    return ListTile(
      leading: UserAvatar(imageUrl: _postAuthor?.profileImageUrl, size: 40),
      title: Text(_postAuthor?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('📍 ${widget.post.location}', style: const TextStyle(fontSize: 12)),
      trailing: Text(
        DateFormat('MMM dd').format(widget.post.createdAt),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildPostImage() {
    return widget.post.imageUrl.startsWith('http')
        ? Image.network(widget.post.imageUrl, width: double.infinity, fit: BoxFit.contain)
        : Image.asset(widget.post.imageUrl, width: double.infinity, fit: BoxFit.contain);
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : null),
              ),
              const Text('Like', style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              IconButton(
                onPressed: _toggleSave,
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? Colors.blue : null),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '${widget.post.likeCount} likes',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: '${_postAuthor?.username} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: widget.post.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey))),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length,
          itemBuilder: (context, index) {
            final comment = _comments[index];
            return FutureBuilder<User?>(
              future: UserService.getUserById(comment.userId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return ListTile(
                  onLongPress: () => _showCommentOptions(comment),
                  leading: UserAvatar(imageUrl: user?.profileImageUrl, size: 30),
                  title: Text(user?.username ?? '...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.content, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(comment.createdAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            onPressed: _isSubmittingComment ? null : _addComment,
            icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
