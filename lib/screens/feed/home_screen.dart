import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wanderlens/widgets/post_card.dart';
import 'package:wanderlens/screens/auth/login_screen.dart';
import 'package:wanderlens/services/notification_service.dart';
import 'package:wanderlens/screens/notification/notification_screen.dart';

import '../../responsive/constrained_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _refreshFeed() async {
    setState(() {});
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
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('WanderLens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: false,
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.getUnreadCountStream(_currentUserId),
            builder: (context, snapshot) {
              final int unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: StreamBuilder<QuerySnapshot>(
          // Fetch all posts ordered by date; status + privacy filtering is
          // done in Dart so that old posts (without a 'status' field) also
          // appear — fromJson defaults missing status to PostStatus.approved.
          stream: _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No posts yet. Start following people!'),
              );
            }

            final List<Post> posts = snapshot.data!.docs
                .map((doc) =>
                    Post.fromJson(doc.data() as Map<String, dynamic>))
                // Feed should only show approved posts.
                // (Old posts without a 'status' field default to approved in Post.fromJson.)
                .where((post) => post.status == PostStatus.approved)
                .where((post) =>
                    post.privacy == PostPrivacy.public ||
                    post.userId == _currentUserId)
                .toList();

            if (posts.isEmpty) {
              return const Center(child: Text('No posts to show.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    currentUserId: _currentUserId,
                    onPostUpdated: () => setState(() {}),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
