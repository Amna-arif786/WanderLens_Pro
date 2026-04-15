import 'package:flutter/material.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/widgets/user_card.dart';

import '../../responsive/constrained_scaffold.dart';

class UserSuggestionsScreen extends StatefulWidget {
  const UserSuggestionsScreen({super.key});

  @override
  State<UserSuggestionsScreen> createState() => _UserSuggestionsScreenState();
}

class _UserSuggestionsScreenState extends State<UserSuggestionsScreen> {
  List<User> _suggestedUsers = [];
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() => _isLoading = true);
    
    try {
      _currentUser = await UserService.getCurrentUser();
      if (_currentUser != null) {
        _suggestedUsers = await UserService.getSuggestedUsers(
          _currentUser!.id,
          limit: 50,
        );
      }
    } catch (e) {
      debugPrint('Error loading suggested users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFriendStatusChanged() {
    // Reload suggestions when friend status changes
    _loadSuggestedUsers();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'People You May Know',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _suggestedUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSuggestedUsers,
                  color: Theme.of(context).colorScheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _suggestedUsers.length,
                    itemBuilder: (context, index) {
                      return UserCard(
                        user: _suggestedUsers[index],
                        currentUserId: _currentUser?.id ?? '',
                        onFriendStatusChanged: _onFriendStatusChanged,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 50,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No suggestions available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'All users are already your friends or have pending requests!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


