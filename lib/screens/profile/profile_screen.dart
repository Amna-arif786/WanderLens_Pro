import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/screens/post/post_detail_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import 'package:wanderlens/screens/profile/edit_profile_screen.dart';
import 'package:wanderlens/screens/settings/settings_screen.dart';
import 'package:wanderlens/screens/follow/friends_list_screen.dart';
import '../../responsive/constrained_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  User? _user;
  bool _isLoadingUser = true;
  late TabController _tabController;
  bool _isCurrentUser = false;
  String? _currentUserId;

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
    _currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = widget.userId ?? _currentUserId;

    if (targetUserId == null) {
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }

    _isCurrentUser = targetUserId == _currentUserId;

    try {
      final user = await UserService.getUserById(targetUserId);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // --- Full Screen Image View Logic ---
  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingUser) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_user == null) return const Scaffold(body: Center(child: Text("User not found")));

    return ConstrainedScaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              backgroundColor: colorScheme.surface,
              centerTitle: true,
              title: Text(_user!.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                if (_isCurrentUser)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                  ),
              ],
            ),
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: _buildTabBar(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _isCurrentUser ? _buildFriendRequestsTab() : _buildFriendsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_user!.id, viewerId: _currentUserId),
      builder: (context, postsSnapshot) {
        final postCount = postsSnapshot.data?.length ?? 0;
        return Column(
          children: [
            const SizedBox(height: 10),
            UserAvatar(imageUrl: _user?.profileImageUrl, size: 90),
            const SizedBox(height: 12),
            Text(_user?.displayName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_user?.bio?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                child: Text(_user!.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Posts', postCount.toString()),
                _buildStatItem('Friends', _user?.friendCount.toString() ?? '0', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => FriendsListScreen(currentUserId: _user!.id, currentUserDisplayName: _user!.displayName, onFriendsChanged: _loadUser)));
                }),
              ],
            ),
            const SizedBox(height: 15),
            _isCurrentUser ? _buildEditProfileButton(colorScheme) : _buildFriendshipButton(),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildEditProfileButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => EditProfileScreen(user: _user!)));
            if (updated == true) _loadUser();
          },
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- Complete Friendship Logic Button ---
  Widget _buildFriendshipButton() {
    if (_currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', whereIn: [_currentUserId, _user!.id])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final docs = snapshot.data!.docs;
        DocumentSnapshot? myRequest;
        DocumentSnapshot? theirRequest;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['senderId'] == _currentUserId && data['receiverId'] == _user!.id) myRequest = doc;
          if (data['senderId'] == _user!.id && data['receiverId'] == _currentUserId) theirRequest = doc;
        }

        Widget button;
        // Case 1: Already Friends
        if (myRequest != null && myRequest['status'] == 'accepted' || theirRequest != null && theirRequest['status'] == 'accepted') {
          button = ElevatedButton.icon(
            onPressed: null, // Yahan unfriend ka logic dalwa saktay hain baad mein
            icon: const Icon(Icons.check, size: 18),
            label: const Text("Friends"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
          );
        }
        // Case 2: I sent a request (Pending)
        else if (myRequest != null && myRequest['status'] == 'pending') {
          button = OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.timer_outlined, size: 18),
            label: const Text("Requested"),
          );
        }
        // Case 3: They sent me a request
        else if (theirRequest != null && theirRequest['status'] == 'pending') {
          button = ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text("Respond"),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
          );
        }
        // Case 4: No request yet
        else {
          button = ElevatedButton.icon(
            onPressed: () => FriendService.sendFriendRequest(_currentUserId!, _user!.id),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text("Add Friend"),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(width: double.infinity, child: button),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: Theme.of(context).colorScheme.onSurface,
      labelColor: Theme.of(context).colorScheme.onSurface,
      unselectedLabelColor: Colors.grey,
      tabs: const [
        Tab(icon: Icon(Icons.grid_on_rounded)),
        Tab(icon: Icon(Icons.assignment_ind_outlined)),
      ],
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_user!.id, viewerId: _currentUserId),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return const Center(child: Text("No posts yet"));

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showFullScreenImage(posts[index].imageUrl),
              onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: posts[index], currentUserId: _currentUserId ?? '', onPostUpdated: _loadUser))),
              child: Image.network(posts[index].imageUrl, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('friend_requests').where('receiverId', isEqualTo: _user!.id).where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("No pending requests"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final requestId = docs[index].id;
            return FutureBuilder<User?>(
              future: UserService.getUserById(data['senderId']),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox.shrink();
                final sender = userSnap.data!;
                return ListTile(
                  leading: UserAvatar(imageUrl: sender.profileImageUrl, size: 40),
                  title: Text(sender.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => FriendService.acceptFriendRequest(requestId)),
                      IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => FriendService.rejectFriendRequest(requestId)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return FriendsListScreen(currentUserId: _user!.id, currentUserDisplayName: _user!.displayName, onFriendsChanged: _loadUser, showAppBar: false);
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate({required this.child});
  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
