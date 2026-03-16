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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const ConstrainedScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return ConstrainedScaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('User not found'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadUser, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ConstrainedScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: widget.userId != null ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: Text(
          _user!.username,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          _buildTabBar(),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _isCurrentUser ? _buildFriendRequestsTab() : _buildFriendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_user!.id),
      builder: (context, postsSnapshot) {
        final postCount = postsSnapshot.data?.length ?? 0;
        
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.withOpacity(0.2), Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: UserAvatar(imageUrl: _user?.profileImageUrl, size: 100),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _user?.displayName ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '@${_user?.username}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              if (_user?.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _user!.bio!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (!_isCurrentUser) _buildFriendshipButton(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Posts', postCount.toString()),
                  _buildStatItem(
                    'Friends',
                    _user?.friendCount.toString() ?? '0',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FriendsListScreen(
                          currentUserId: _user!.id,
                          currentUserDisplayName: _user!.displayName,
                          onFriendsChanged: _loadUser,
                        ),
                      ),
                    ),
                  ),
                  if (_isCurrentUser)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('friend_requests')
                          .where('receiverId', isEqualTo: _user!.id)
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final reqCount = snapshot.data?.docs.length ?? 0;
                        return _buildStatItem('Requests', reqCount.toString(), onTap: () => _tabController.animateTo(1));
                      },
                    ),
                ],
              ),
              if (_isCurrentUser) ...[
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (context) => EditProfileScreen(user: _user!)),
                        );
                        if (updated == true) _loadUser();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        elevation: 0,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendshipButton() {
    if (_currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', whereIn: [_currentUserId, _user!.id])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final requests = snapshot.data!.docs;
        DocumentSnapshot? myRequest;
        DocumentSnapshot? theirRequest;

        for (var doc in requests) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['senderId'] == _currentUserId && data['receiverId'] == _user!.id) {
            myRequest = doc;
          } else if (data['senderId'] == _user!.id && data['receiverId'] == _currentUserId) {
            theirRequest = doc;
          }
        }

        Widget button;
        if (myRequest != null) {
          final status = myRequest['status'];
          if (status == 'pending') {
            button = OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.timer_outlined, size: 18), label: const Text('Requested'));
          } else {
            button = ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.check, size: 18), label: const Text('Friends'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green));
          }
        } else if (theirRequest != null) {
          button = ElevatedButton.icon(onPressed: () => _tabController.animateTo(1), icon: const Icon(Icons.person_add, size: 18), label: const Text('Respond'));
        } else {
          button = ElevatedButton.icon(
            onPressed: () async => await FriendService.sendFriendRequest(_currentUserId!, _user!.id),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add Friend'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(width: double.infinity, child: button),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary, 
          borderRadius: BorderRadius.circular(12)
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.grid_view_rounded, size: 18),
                SizedBox(width: 8),
                Text('Posts'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isCurrentUser ? Icons.mail_outline_rounded : Icons.people_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text(_isCurrentUser ? 'Requests' : 'Friends'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<List<Post>>(
      stream: PostService.getPostsStreamByUserId(_user!.id),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text('No posts yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostDetailScreen(post: post, currentUserId: _currentUserId ?? '', onPostUpdated: _loadUser))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(post.imageUrl, fit: BoxFit.cover),
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
          .where('receiverId', isEqualTo: _user!.id)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No pending requests', style: TextStyle(color: Colors.grey)));

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
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
                  child: ListTile(
                    leading: UserAvatar(imageUrl: sender.profileImageUrl, size: 45),
                    title: Text(sender.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => FriendService.acceptFriendRequest(requestId)),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => FriendService.rejectFriendRequest(requestId)),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: sender.id))),
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
     return FriendsListScreen(
       currentUserId: _user!.id,
       currentUserDisplayName: _user!.displayName,
       onFriendsChanged: _loadUser,
       showAppBar: false,
     );
  }
}
