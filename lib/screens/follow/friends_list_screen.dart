import 'package:flutter/material.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

import '../../responsive/constrained_scaffold.dart';

/// Shows current user's friends list with unfriend option..
class FriendsListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserDisplayName;
  final VoidCallback? onFriendsChanged;

  const FriendsListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserDisplayName,
    this.onFriendsChanged,
  });

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  List<User> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final friends = await FriendService.getFriends(widget.currentUserId);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unfriend(User friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfriend'),
        content: Text(
          'Remove ${friend.displayName} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FriendService.removeFriend(widget.currentUserId, friend.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.displayName} removed from friends')),
        );
        _loadFriends();
        widget.onFriendsChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfriend: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Friends',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _friends.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No friends yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for users in Explore to add friends',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            imageUrl: friend.profileImageUrl,
                            size: 50,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      friend.displayName,
                                      style:
                                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (friend.isVerified) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${friend.username}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _unfriend(friend),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Unfriend'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
