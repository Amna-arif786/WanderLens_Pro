import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/comment.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/comment_service.dart';
import 'package:wanderlens/services/like_service.dart';
import 'package:wanderlens/services/wishlist_service.dart';
import 'package:wanderlens/screens/profile/profile_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import 'package:wanderlens/utils/location_constants.dart';

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
  Post? _editedPost; 
  User? _postAuthor;
  List<Comment> _comments = [];
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  Post get _displayPost => _editedPost ?? widget.post;

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
      final author = await UserService.getUserById(_displayPost.userId);
      final comments = await CommentService.getCommentsByPostId(_displayPost.id);
      final isLiked = await LikeService.isPostLikedByUser(_displayPost.id, widget.currentUserId);
      final isSaved = await WishlistService.isPostInWishlist(_displayPost.id, widget.currentUserId);

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
      await LikeService.toggleLike(_displayPost.id, widget.currentUserId);
      widget.onPostUpdated?.call();
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) return;
    setState(() => _isSaved = !_isSaved);
    try {
      await WishlistService.toggleWishlist(_displayPost.id, widget.currentUserId);
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
        postId: _displayPost.id,
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

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Post'),
            onTap: () {
              Navigator.pop(context);
              _showEditPostDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete();
            },
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog() {
    final captionController = TextEditingController(text: _displayPost.caption);
    final locationController = TextEditingController(text: _displayPost.location);
    final cityController = TextEditingController(text: _displayPost.cityName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionController,
                decoration: const InputDecoration(labelText: 'Caption'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location/Monument'),
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _displayPost.cityName),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return LocationConstants.pakistanCities.where((String city) {
                    return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  cityController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onFieldSubmitted: (value) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      labelText: 'City',
                      hintText: 'e.g., Lahore, Karachi',
                    ),
                    onChanged: (value) => cityController.text = value,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final updatedPost = _displayPost.copyWith(
                caption: captionController.text.trim(),
                location: locationController.text.trim(),
                cityName: cityController.text.trim(),
              );
              await PostService.updatePost(updatedPost);
              setState(() => _editedPost = updatedPost);
              Navigator.pop(context);
              widget.onPostUpdated?.call();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PostService.deletePost(_displayPost.id);
      if (mounted) {
        widget.onPostUpdated?.call();
        Navigator.pop(context); 
      }
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
              await CommentService.deleteComment(_displayPost.id, comment.id);
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
              await CommentService.updateComment(_displayPost.id, comment.id, controller.text);
              Navigator.pop(context);
              _loadPostDetails();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthor = _displayPost.userId == widget.currentUserId;

    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Post Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (isAuthor)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showPostOptions,
            ),
        ],
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
      leading: GestureDetector(
        onTap: () => _navigateToProfile(_displayPost.userId),
        child: UserAvatar(imageUrl: _postAuthor?.profileImageUrl, size: 40),
      ),
      title: GestureDetector(
        onTap: () => _navigateToProfile(_displayPost.userId),
        child: Text(_postAuthor?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      subtitle: Text('📍 ${_displayPost.location}, ${_displayPost.cityName}', style: const TextStyle(fontSize: 12)),
      trailing: Text(
        DateFormat('MMM dd').format(_displayPost.createdAt),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildPostImage() {
    return _displayPost.imageUrl.startsWith('http')
        ? Image.network(_displayPost.imageUrl, width: double.infinity, fit: BoxFit.contain)
        : Image.asset(_displayPost.imageUrl, width: double.infinity, fit: BoxFit.contain);
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
              '${_displayPost.likeCount} likes',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => _navigateToProfile(_displayPost.userId),
                      child: Text('${_postAuthor?.username ?? ""} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextSpan(text: _displayPost.caption),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(comment.userId),
                        child: UserAvatar(imageUrl: user?.profileImageUrl, size: 35),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _navigateToProfile(comment.userId),
                              child: Text(
                                user?.username ?? '...',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 2),
                            GestureDetector(
                              onLongPress: () => _showCommentOptions(comment),
                              child: Text(
                                comment.content,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, HH:mm').format(comment.createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
