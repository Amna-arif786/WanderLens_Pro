import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/cloudinary_profile_picture_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';

import '../../responsive/constrained_scaffold.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController(text: widget.user.location ?? '');
    _currentProfileImageUrl = widget.user.profileImageUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isUploadingImage = true);
    
    final oldUrl = _currentProfileImageUrl;

    try {
      // Read image as bytes for cross-platform compatibility (Web & Mobile)
      final Uint8List imageBytes = await image.readAsBytes();
      
      // Call the updated service method
      final String downloadUrl = await CloudinaryProfileService.uploadProfilePictureFromBytes(imageBytes);
      
      setState(() {
        _currentProfileImageUrl = downloadUrl;
      });

      // Delete the old image safely
      if (oldUrl != null) {
        await CloudinaryProfileService.deleteOldImage(oldUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture uploaded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedUser = widget.user.copyWith(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        profileImageUrl: _currentProfileImageUrl,
      );

      await UserService.updateUser(updatedUser);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadImage,
                  child: Stack(
                    children: [
                      UserAvatar(
                        imageUrl: _currentProfileImageUrl,
                        size: 120,
                        showCameraIcon: true,
                      ),
                      if (_isUploadingImage)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
