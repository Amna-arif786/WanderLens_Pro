import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wanderlens/screens/feed/home_screen.dart';
import 'package:wanderlens/screens/explore/explore_screen.dart';
import 'package:wanderlens/screens/create/create_post_screen.dart';
import 'package:wanderlens/screens/wishlist/wishlist_screen.dart';
import 'package:wanderlens/screens/profile/profile_screen.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

import '../responsive/constrained_scaffold.dart';

class MainNavigation extends StatefulWidget {
  MainNavigation({Key? key}) : super(key: key ?? navigationKey);

  static final GlobalKey<MainNavigationState> navigationKey = GlobalKey<MainNavigationState>();

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  // Screen key taake create post screen refresh ho sake
  Key _createScreenKey = UniqueKey();

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) {
        _createScreenKey = UniqueKey(); // Create tab pr jaty hi refresh
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final List<Widget> _screens = [
      const HomeScreen(),
      const ExploreScreen(),
      CreatePostScreen(key: _createScreenKey), // Key di hai taake refresh ho sake
      const WishlistScreen(),
      const ProfileScreen(),
    ];

    return ConstrainedScaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            String? profileUrl;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              profileUrl = data['profileImageUrl'];
            }

            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: switchTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
                const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Explore'),
                const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), activeIcon: Icon(Icons.add_circle), label: 'Create'),
                const BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), activeIcon: Icon(Icons.bookmark), label: 'Wishlist'),
                BottomNavigationBarItem(
                  icon: UserAvatar(
                    key: ValueKey(profileUrl), 
                    imageUrl: profileUrl, 
                    size: 24
                  ),
                  activeIcon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    child: UserAvatar(
                      key: ValueKey(profileUrl), 
                      imageUrl: profileUrl, 
                      size: 22
                    ),
                  ),
                  label: 'Profile',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
