import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/image_verification_service.dart';
import 'package:wanderlens/storage/cloudinary_service.dart';
import 'package:wanderlens/screens/main_navigation.dart';

import '../../responsive/constrained_scaffold.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  
  Uint8List? _selectedImageBytes;
  PostPrivacy _privacy = PostPrivacy.public;
  bool _isUploading = false;
  bool _isVerifying = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add Photo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create a post')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _isUploading = true;
    });

    try {
      final isVerified = await ImageVerificationService.verifyTravelImageFromBytes(
        _selectedImageBytes!,
        _locationController.text.trim(),
      );

      setState(() => _isVerifying = false);

      if (!isVerified) {
        setState(() => _isUploading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Image Verification Failed'),
              content: const Text(
                'Your image doesn\'t appear to show a travel destination, monument, or historical place. Please upload an image that matches our community guidelines.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final uploadedUrl = await CloudinaryService.uploadPostImageFromBytes(_selectedImageBytes!);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image..')),
          );
        }
        setState(() => _isUploading = false);
        return;
      }

      await PostService.createPost(
        userId: currentUser.id,
        imageUrl: uploadedUrl,
        caption: _captionController.text.trim(),
        location: _locationController.text.trim(),
        cityName: _cityController.text.trim(),
        privacy: _privacy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear the form
        _captionController.clear();
        _locationController.clear();
        _cityController.clear();
        setState(() {
          _selectedImageBytes = null;
          _privacy = PostPrivacy.public;
        });

        // Navigate to Home Tab (Index 0) to see the new post
        MainNavigation.navigationKey.currentState?.switchTab(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Post',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _createPost,
            child: _isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Text(
                    'Post',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildFormFields(),
              const SizedBox(height: 24),
              _buildPrivacySettings(),
              const SizedBox(height: 24),
              _buildAIVerificationInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _selectedImageBytes!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Photo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your travel moments',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _captionController,
          decoration: InputDecoration(
            labelText: 'Caption',
            hintText: 'Share your experience...',
            prefixIcon: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a caption';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Location/Monument',
            hintText: 'e.g., Eiffel Tower, Taj Mahal',
            prefixIcon: Icon(Icons.place_outlined, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the location or monument name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cityController,
          decoration: InputDecoration(
            labelText: 'City/Country',
            hintText: 'e.g., Paris, France',
            prefixIcon: Icon(Icons.location_city_outlined, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the city or country';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<PostPrivacy>(
            value: PostPrivacy.public,
            groupValue: _privacy,
            onChanged: (value) => setState(() => _privacy = value!),
            title: const Text('Public'),
            subtitle: const Text('Everyone can see this post'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          RadioListTile<PostPrivacy>(
            value: PostPrivacy.friends,
            groupValue: _privacy,
            onChanged: (value) => setState(() => _privacy = value!),
            title: const Text('Friends Only'),
            subtitle: const Text('Only your friends can see this post'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAIVerificationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Verification',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your image will be verified using AI to ensure it shows a travel destination, monument, or historical place. Only verified posts are accepted.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          if (_isVerifying)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verifying image...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
