import 'package:flutter/material.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/screens/profile/profile_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import '../../responsive/constrained_scaffold.dart';

class FriendsListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserDisplayName;
  final VoidCallback? onFriendsChanged;
  final bool showAppBar;

  const FriendsListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserDisplayName,
    this.onFriendsChanged,
    this.showAppBar = true,
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
    if (!mounted) return;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unfriend(User friend) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Friend?', style: TextStyle(color: colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to unfriend ${friend.displayName}?',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: colorScheme.primary))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FriendService.removeFriend(widget.currentUserId, friend.id);
      _loadFriends();
      widget.onFriendsChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.showAppBar) return _buildBody();

    return ConstrainedScaffold(
      // Dynamic background color
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Friends',
          style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 100, color: colorScheme.primary.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
                'No friends yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)
            ),
            Text(
                'Start connecting with travelers!',
                style: TextStyle(color: colorScheme.onSurfaceVariant)
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Friends Count Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          alignment: Alignment.centerLeft,
          child: Text(
            '${_friends.length} Friends',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.primary
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
              return _buildFriendCard(friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(User friend) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Card color automatically adjusts
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(isDark ? 0.2 : 0.5)
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)
            ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen(userId: friend.id))
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 3),
                ),
                child: UserAvatar(imageUrl: friend.profileImageUrl, size: 55),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface
                      ),
                    ),
                    Text(
                      '@${friend.username}',
                      style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13
                      ),
                    ),
                  ],
                ),
              ),
              // Professional Red Outlined Button for Unfriend
              OutlinedButton(
                onPressed: () => _unfriend(friend),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                    'Unfriend',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}