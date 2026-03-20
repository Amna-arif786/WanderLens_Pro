import 'package:flutter/material.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/models/user.dart';
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

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<User> _searchResults = [];
  List<User> _suggestedUsers = [];
  User? _currentUser;
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
        _suggestedUsers = await UserService.getSuggestedUsers(_currentUser!.id, limit: 15);
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
      if (mounted) setState(() {
        _searchResults = results;
        _isUserSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _searchResults = [];
        _isUserSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedScaffold(
      // Hardcoded color ki jagah theme ka surface color
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
            'Explore',
            style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold
            )
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedTab == _ExploreTab.posts
                  ? _buildPostSearchContent()
                  : _buildUserSearchContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        // Dark mode mein halka grey/navy black box professional lagta hai
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: _selectedTab == _ExploreTab.posts
              ? 'Search locations (e.g. Hunza)...'
              : 'Search travelers...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              if (_selectedTab == _ExploreTab.users) _searchUsers('');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
          _buildTab(_ExploreTab.posts, 'Locations', Icons.map_outlined),
          const SizedBox(width: 12),
          _buildTab(_ExploreTab.users, 'Travelers', Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildTab(_ExploreTab tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
            _searchQuery = _searchController.text.trim();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? Colors.transparent : colorScheme.outlineVariant.withOpacity(0.5)
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  icon,
                  size: 18,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostSearchContent() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 80, color: colorScheme.primary.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
                'Discover new destinations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)
            ),
            Text(
                'Search for Murree, Hunza, or Kashmir...',
                style: TextStyle(color: colorScheme.onSurfaceVariant)
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').where('privacy', isEqualTo: 'public').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final query = _searchQuery.toLowerCase();
        final docs = snapshot.data?.docs ?? [];

        final filteredPosts = docs.map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>))
            .where((post) =>
        post.location.toLowerCase().contains(query) ||
            post.cityName.toLowerCase().contains(query))
            .toList();

        if (filteredPosts.isEmpty) {
          return Center(child: Text('No posts found for "$_searchQuery"', style: TextStyle(color: colorScheme.onSurface)));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            return PostCard(
              key: ValueKey(filteredPosts[index].id),
              post: filteredPosts[index],
              currentUserId: _currentUser?.id ?? '',
            );
          },
        );
      },
    );
  }

  Widget _buildUserSearchContent() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_searchQuery.isEmpty) {
      return ListView(
        children: [
          _buildSuggestedSection(),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(Icons.person_search_outlined, size: 60, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
                const SizedBox(height: 10),
                Text(
                    'Search for other travelers',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_isUserSearching) return const Center(child: CircularProgressIndicator());

    if (_searchResults.isEmpty) {
      return Center(child: Text('No users found matching "$_searchQuery"', style: TextStyle(color: colorScheme.onSurface)));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return UserCard(
          user: _searchResults[index],
          currentUserId: _currentUser?.id ?? '',
          onFriendStatusChanged: _loadCurrentUserAndSuggestions,
        );
      },
    );
  }

  Widget _buildSuggestedSection() {
    if (_suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Discover Travelers',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface
            ),
          ),
        ),
        SizedBox(
          height: 170, // Thoda height barha di taake padding sahi ho
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = _suggestedUsers[index];
              return _buildSuggestedUserItem(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedUserItem(User user) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          // Profile navigation logic
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                    ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user.displayName,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.onSurface
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '@${user.username}',
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}