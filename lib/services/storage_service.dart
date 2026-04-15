import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users';
  static const String _postsKey = 'posts';
  static const String _commentsKey = 'comments';
  static const String _likesKey = 'likes';
  static const String _friendRequestsKey = 'friend_requests';
  static const String _userFriendsKey = 'user_friends';
  static const String _wishlistsKey = 'wishlists';

  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  static Future<void> saveCurrentUser(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_currentUserKey, userId);
  }

  static Future<String?> getCurrentUser() async {
    final prefs = await _prefs;
    return prefs.getString(_currentUserKey);
  }

  static Future<void> clearCurrentUser() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUserKey);
  }

  static Future<void> saveList<T>(String key, List<T> items, Map<String, dynamic> Function(T) toJson) async {
    try {
      final prefs = await _prefs;
      final jsonList = items.map((item) => toJson(item)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving list for key $key: $e');
    }
  }

  static Future<List<T>> getList<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final prefs = await _prefs;
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      final items = <T>[];

      for (final json in jsonList) {
        try {
          if (json is Map<String, dynamic>) {
            items.add(fromJson(json));
          }
        } catch (e) {
          debugPrint('Error parsing item in $key: $e');
          continue;
        }
      }

      await saveList(key, items, (item) {
        try {
          return (item as dynamic).toJson() as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      });

      return items;
    } catch (e) {
      debugPrint('Error loading list for key $key: $e');
      return [];
    }
  }

  // Specific getters and setters
  static Future<void> saveUsers(List<dynamic> users) => saveList(_usersKey, users, (user) => user.toJson());
  static Future<List<T>> getUsers<T>(T Function(Map<String, dynamic>) fromJson) => getList(_usersKey, fromJson);

  static Future<void> savePosts(List<dynamic> posts) => saveList(_postsKey, posts, (post) => post.toJson());
  static Future<List<T>> getPosts<T>(T Function(Map<String, dynamic>) fromJson) => getList(_postsKey, fromJson);

  static Future<void> saveComments(List<dynamic> comments) => saveList(_commentsKey, comments, (comment) => comment.toJson());
  static Future<List<T>> getComments<T>(T Function(Map<String, dynamic>) fromJson) => getList(_commentsKey, fromJson);

  static Future<void> saveLikes(List<dynamic> likes) => saveList(_likesKey, likes, (like) => like.toJson());
  static Future<List<T>> getLikes<T>(T Function(Map<String, dynamic>) fromJson) => getList(_likesKey, fromJson);

  static Future<void> saveFriendRequests(List<dynamic> requests) => saveList(_friendRequestsKey, requests, (request) => request.toJson());
  static Future<List<T>> getFriendRequests<T>(T Function(Map<String, dynamic>) fromJson) => getList(_friendRequestsKey, fromJson);

  static Future<void> saveUserFriends(List<dynamic> friends) => saveList(_userFriendsKey, friends, (friend) => friend.toJson());
  static Future<List<T>> getUserFriends<T>(T Function(Map<String, dynamic>) fromJson) => getList(_userFriendsKey, fromJson);

  static Future<void> saveWishlists(List<dynamic> wishlists) => saveList(_wishlistsKey, wishlists, (wishlist) => wishlist.toJson());
  static Future<List<T>> getWishlists<T>(T Function(Map<String, dynamic>) fromJson) => getList(_wishlistsKey, fromJson);
}