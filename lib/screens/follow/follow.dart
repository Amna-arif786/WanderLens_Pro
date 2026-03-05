import 'package:flutter/material.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

import '../../responsive/constrained_scaffold.dart';

/// FollowScreen displays either a list of 'Followers' or 'Following' for a specific user.
class FollowScreen extends StatefulWidget {
  final String userId;
  final String username;
  final bool initialIsFollowing; // true for Following, false for Followers..

  const FollowScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialIsFollowing = true,
  });

  @override
  State<FollowScreen> createState() => _FollowScreenState();
}

class _FollowScreenState extends State<FollowScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _followers = [];
  List<User> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialIsFollowing ? 1 : 0,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Fetches both followers and following lists from Firebase..
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final followersData = await FriendService.getFollowers(widget.userId);
      final followingData = await FriendService.getFollowing(widget.userId);
      
      if (mounted) {
        setState(() {
          _followers = followersData;
          _following = followingData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: Text(widget.username),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers, 'No followers yet'),
                _buildUserList(_following, 'Not following anyone yet'),
              ],
            ),
    );
  }

  /// Helper widget to build the list of users..
  Widget _buildUserList(List<User> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: UserAvatar(imageUrl: user.profileImageUrl, size: 40),
          title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('@${user.username}'),
          onTap: () {
            // TODO: Navigate to this user's profile..
          },
        );
      },
    );
  }
}
