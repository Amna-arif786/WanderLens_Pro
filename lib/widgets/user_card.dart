import 'package:flutter/material.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/friend_request.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

class UserCard extends StatefulWidget {
  final User user;
  final String currentUserId;
  final VoidCallback? onFriendStatusChanged;

  const UserCard({
    super.key,
    required this.user,
    required this.currentUserId,
    this.onFriendStatusChanged,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  bool _isLoading = false;
  bool _isFriend = false;
  bool _hasPendingRequest = false;
  bool _isRequestSent = false;
  FriendRequest? _pendingRequest;

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();
  }

  Future<void> _checkFriendStatus() async {
    setState(() => _isLoading = true);

    try {
      // Check if already friends
      _isFriend = await FriendService.areUsersFriends(
        widget.currentUserId,
        widget.user.id,
      );

      // Check for pending requests
      _pendingRequest = await FriendService.getFriendRequest(
        widget.currentUserId,
        widget.user.id,
      );

      if (_pendingRequest != null) {
        _isRequestSent = true;
        _hasPendingRequest =
            _pendingRequest!.status == FriendRequestStatus.pending;
      } else {
        // Check reverse request
        final reverseRequest = await FriendService.getFriendRequest(
          widget.user.id,
          widget.currentUserId,
        );
        if (reverseRequest != null &&
            reverseRequest.status == FriendRequestStatus.pending) {
          _hasPendingRequest = true;
        }
      }
    } catch (e) {
      print('Error checking friend status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isLoading || _isFriend || _isRequestSent) return;

    setState(() => _isLoading = true);

    try {
      await FriendService.sendFriendRequest(
        widget.currentUserId,
        widget.user.id,
      );

      setState(() {
        _isRequestSent = true;
        _hasPendingRequest = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to ${widget.user.displayName}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      widget.onFriendStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptFriendRequest() async {
    if (_pendingRequest == null) return;

    setState(() => _isLoading = true);

    try {
      await FriendService.acceptFriendRequest(_pendingRequest!.id);

      setState(() {
        _isFriend = true;
        _hasPendingRequest = false;
        _isRequestSent = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('You are now friends with ${widget.user.displayName}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      widget.onFriendStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting friend request: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: widget.user.profileImageUrl,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.user.displayName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.user.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${widget.user.username}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  if (widget.user.bio != null &&
                      widget.user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.user.bio!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.user.location != null &&
                      widget.user.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.user.location!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Friends',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    if (_hasPendingRequest && !_isRequestSent) {
      // Request received - show accept button
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: _acceptFriendRequest,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Accept'),
          ),
        ],
      );
    }

    if (_isRequestSent) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text('Pending'),
      );
    }

    return ElevatedButton(
      onPressed: _sendFriendRequest,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Text('Add Friend'),
    );
  }
}
