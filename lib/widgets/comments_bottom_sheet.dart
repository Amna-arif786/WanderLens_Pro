import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/comment.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/comment_service.dart';
import 'package:wanderlens/screens/profile/profile_screen.dart';
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

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)));
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
              _loadComments();
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
              _loadComments();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Flexible(
            child: _isLoading
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                : _comments.isEmpty
                    ? const SizedBox(height: 200, child: Center(child: Text('No comments yet', style: TextStyle(color: Colors.grey))))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                IconButton(onPressed: _isSubmitting ? null : _addComment, icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary)),
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
        final bool isMyComment = comment.userId == widget.currentUserId;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(onTap: () => _navigateToProfile(context, comment.userId), child: UserAvatar(imageUrl: user?.profileImageUrl, size: 35)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(context, comment.userId),
                      child: Text(user?.username ?? '...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 2),
                    Text(comment.content, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM dd, HH:mm').format(comment.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              if (isMyComment)
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                  onPressed: () => _showCommentOptions(comment),
                ),
            ],
          ),
        );
      },
    );
  }
}
