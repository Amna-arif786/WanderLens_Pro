# WanderLens - Travel Social Media App Architecture

## App Overview
WanderLens is a sophisticated travel-focused social media platform where users share travel moments, discover historical places and monuments, and build connections with fellow travelers. The app uses AI-powered image verification to ensure content authenticity.

## Core Features

### 1. Authentication & User Management
- User registration/login system
- Profile creation with travel-verified profile pictures
- User profile management and settings

### 2. Content Creation & Sharing
- Image post creation with location tagging
- AI-powered image verification using Gemini API
- Automatic rejection of irrelevant images
- Mandatory location/city mention in captions
- Travel journal style posts

### 3. Social Interactions
- Friend request system
- Post privacy controls (Public/Friends only)
- Like, comment, and save functionality
- Personal wishlist for saved posts

### 4. Discovery & Exploration
- Feed with travel posts from friends and public posts
- Location-based content discovery
- Historical places and monuments exploration

## Technical Architecture

### Data Models (`lib/models/`)
1. **User Model**
   - id, username, email, displayName
   - profileImageUrl, bio, location
   - friendCount, postCount
   - isVerified, createdAt, updatedAt

2. **Post Model**
   - id, userId, imageUrl, caption
   - location, cityName, coordinates
   - privacy (public/friends), isVerified
   - likeCount, commentCount, saveCount
   - createdAt, updatedAt

3. **Comment Model**
   - id, postId, userId, content
   - createdAt, updatedAt

4. **Like Model**
   - id, postId, userId, createdAt

5. **FriendRequest Model**
   - id, senderId, receiverId, status
   - createdAt, updatedAt

6. **Wishlist Model**
   - id, userId, postId, createdAt

7. **UserFriend Model**
   - id, userId, friendId, createdAt

### Services (`lib/services/`)
1. **UserService** - User management and authentication
2. **PostService** - Post creation, retrieval, and management
3. **CommentService** - Comment operations
4. **LikeService** - Like/unlike functionality
5. **FriendService** - Friend requests and relationships
6. **WishlistService** - Wishlist management
7. **ImageVerificationService** - Gemini API integration
8. **StorageService** - Local data persistence

### UI Structure (`lib/screens/`)
1. **Authentication Flow**
   - SplashScreen
   - LoginScreen
   - RegisterScreen

2. **Main Navigation**
   - HomeScreen (Feed)
   - ExploreScreen (Discover)
   - CreatePostScreen
   - WishlistScreen
   - ProfileScreen

3. **Secondary Screens**
   - PostDetailScreen
   - UserProfileScreen
   - EditProfileScreen
   - FriendRequestsScreen
   - SettingsScreen

### Widgets (`lib/widgets/`)
- PostCard - Main post display widget
- CommentSection - Comments display and input
- UserAvatar - Profile picture display
- CustomButton - Themed buttons
- ImagePicker - Custom image selection
- LocationSelector - Location input component

## Design System
- **Color Palette**: Sophisticated travel-inspired colors
  - Primary: Deep teal (#006B5C) 
  - Secondary: Warm amber (#FF8F00)
  - Background: Clean whites and soft grays
- **Typography**: Inter font family with clear hierarchy
- **Style**: Modern, clean design with generous spacing
- **Components**: Card-based layouts, rounded corners, minimal shadows

## Implementation Plan
1. Set up dependencies and basic project structure
2. Create data models and services with local storage
3. Implement authentication flow
4. Build main navigation and home feed
5. Create post creation flow with image verification
6. Implement social features (friends, likes, comments)
7. Add wishlist functionality
8. Polish UI/UX and add animations
9. Test and debug the complete application

## Technical Dependencies
- Local storage for data persistence
- Image picker for photo selection
- HTTP client for Gemini API integration
- State management for app state
- Custom animations and transitions