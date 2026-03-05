import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/friend_request.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/screens/auth/login_screen.dart';
import 'package:wanderlens/screens/post/post_detail_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import 'package:wanderlens/screens/profile/edit_profile_screen.dart';
import 'package:wanderlens/screens/settings/settings_screen.dart';
import 'package:wanderlens/screens/follow/friends_list_screen.dart';
import '../../responsive/constrained_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  User? _currentUser;
  bool _isLoadingUser = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await UserService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserService.logout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const ConstrainedScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error loading profile'),
            ElevatedButton(onPressed: _loadUser, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentUser!.username,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit_profile':
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(user: _currentUser!),
                    ),
                  );
                  if (updated == true) _loadUser();
                  break;
                case 'settings':
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit_profile',
                child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit Profile')]),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('Settings')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildFriendRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_currentUser!.id),
      builder: (context, postsSnapshot) {
        final postCount = postsSnapshot.data?.length ?? 0;
        
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              UserAvatar(imageUrl: _currentUser?.profileImageUrl, size: 100),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentUser?.displayName ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_currentUser?.isVerified == true) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.verified, color: Theme.of(context).colorScheme.primary, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '@${_currentUser?.username}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (_currentUser?.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(_currentUser!.bio!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Posts', postCount.toString()),
                  _buildStatItem(
                    'Friends',
                    _currentUser?.friendCount.toString() ?? '0',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FriendsListScreen(
                          currentUserId: _currentUser!.id,
                          currentUserDisplayName: _currentUser!.displayName,
                          onFriendsChanged: _loadUser,
                        ),
                      ),
                    ),
                  ),
                  // Requests count updated via StreamBuilder below
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('receiverId', isEqualTo: _currentUser!.id)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final reqCount = snapshot.data?.docs.length ?? 0;
                      return _buildStatItem('Requests', reqCount.toString(), onTap: () => _tabController.animateTo(1));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ],
    );
    return onTap != null ? InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: content)) : content;
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest, 
        borderRadius: BorderRadius.circular(12)
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary, 
          borderRadius: BorderRadius.circular(10)
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.grid_on, size: 18), SizedBox(width: 8), Text('Posts', style: TextStyle(fontWeight: FontWeight.bold))])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_add, size: 18), SizedBox(width: 8), Text('Requests', style: TextStyle(fontWeight: FontWeight.bold))])),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_currentUser!.id),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No posts yet', style: Theme.of(context).textTheme.titleLarge),
                const Text('Share your travel adventures!'),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostDetailScreen(post: post, currentUserId: _currentUser!.id, onPostUpdated: _loadUser))),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(image: post.imageUrl.startsWith('http') ? NetworkImage(post.imageUrl) : AssetImage(post.imageUrl) as ImageProvider, fit: BoxFit.cover),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('receiverId', isEqualTo: _currentUser!.id)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No pending friend requests'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final requestData = docs[index].data() as Map<String, dynamic>;
            final senderId = requestData['senderId'];
            final requestId = docs[index].id;

            return FutureBuilder<User?>(
              future: UserService.getUserById(senderId),
              builder: (context, userSnapshot) {
                final sender = userSnapshot.data;
                if (sender == null) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: UserAvatar(imageUrl: sender.profileImageUrl, size: 45),
                    title: Text(sender.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('@${sender.username}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () async {
                            await FriendService.acceptFriendRequest(requestId);
                            _loadUser();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () async {
                            await FriendService.rejectFriendRequest(requestId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
