import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final bool showCameraIcon; // Naya option camera icon dikhane ke liye

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.onTap,
    this.showCameraIcon = false, // Default mein false rakha hai
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Main Avatar
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? (imageUrl!.startsWith('http')
                      ? Image.network(
                          imageUrl!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(context),
                        )
                      : Image.asset(
                          imageUrl!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(context),
                        ))
                  : _buildDefaultAvatar(context),
            ),
          ),
          
          // Camera Icon (Sirf tab nazar aayega jab showCameraIcon true ho)
          if (showCameraIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: size * 0.2, // Icon size avatar ke mutabiq adjust hoga
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}
