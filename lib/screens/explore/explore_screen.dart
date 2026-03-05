import 'package:flutter/material.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/widgets/post_card.dart';
import 'package:wanderlens/widgets/user_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../responsive/constrained_scaffold.dart';

enum _ExploreTab { posts, users }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<User> _searchResults = [];
  List<User> _suggestedUsers = [];
  User? _currentUser;
  bool _isLoading = false;
  bool _isUserSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  _ExploreTab _selectedTab = _ExploreTab.posts;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndSuggestions() async {
    try {
      _currentUser = await UserService.getCurrentUser();
      if (_currentUser != null) {
        _suggestedUsers = await UserService.getSuggestedUsers(_currentUser!.id, limit: 10);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading user suggestions: $e');
    }
  }

  Future<void> _searchUsers(String? query) async {
    final q = query?.trim() ?? '';
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isUserSearching = false;
        });
      }
      return;
    }
    setState(() => _isUserSearching = true);
    try {
      final results = await UserService.searchUsers(q, excludeUserId: _currentUser?.id);
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) setState(() => _searchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: _selectedTab == _ExploreTab.posts 
                ? _buildPostSearchContent() 
                : _buildUserSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _selectedTab == _ExploreTab.posts 
              ? 'Search by location...' 
              : 'Search users...',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim());
          if (_selectedTab == _ExploreTab.users) {
            _searchUsers(value);
          }
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab(_ExploreTab.posts, 'Locations'),
          const SizedBox(width: 12),
          _buildTab(_ExploreTab.users, 'Users'),
        ],
      ),
    );
  }

  Widget _buildTab(_ExploreTab tab, String label) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostSearchContent() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Search for travel locations to see posts', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('location', isGreaterThanOrEqualTo: _searchQuery)
          .where('location', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts found for this location'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = Post.fromJson(docs[index].data() as Map<String, dynamic>);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostCard(
                post: post,
                currentUserId: _currentUser?.id ?? '',
                onPostUpdated: () => setState(() {}),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserSearchContent() {
    if (_searchQuery.isEmpty) {
       return ListView.builder(
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, index) => UserCard(
          user: _suggestedUsers[index],
          currentUserId: _currentUser?.id ?? '',
          onFriendStatusChanged: _loadCurrentUserAndSuggestions,
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => UserCard(
        user: _searchResults[index],
        currentUserId: _currentUser?.id ?? '',
        onFriendStatusChanged: _loadCurrentUserAndSuggestions,
      ),
    );
  }
}
