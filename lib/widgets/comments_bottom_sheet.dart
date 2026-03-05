import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/comment.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/comment_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

class CommentsBottomSheet extends StatefulWidget {
  final Post post;
  final String currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  List<Comment> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await CommentService.getCommentsByPostId(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() => _isSubmitting = true);
    try {
      await CommentService.createComment(
        postId: widget.post.id,
        userId: widget.currentUserId,
        content: _commentController.text.trim(),
      );
      _commentController.clear();
      _loadComments();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Comments',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          
          // Comments List
          Flexible(
            child: _isLoading
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                : _comments.isEmpty
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // Input field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : _addComment,
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return FutureBuilder<User?>(
      future: UserService.getUserById(comment.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(imageUrl: user?.profileImageUrl, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        children: [
                          TextSpan(
                            text: '${user?.username ?? '...'} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: comment.content),
                        ],
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
  }
}
