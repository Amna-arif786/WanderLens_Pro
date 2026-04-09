import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/post_service.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/image_verification_service.dart';
import 'package:wanderlens/storage/cloudinary_service.dart';
import 'package:wanderlens/screens/main_navigation.dart';
import 'package:wanderlens/utils/location_constants.dart';
import '../../responsive/constrained_scaffold.dart';

// Rejection dialog content per reason
const Map<ImageRejectionReason, _RejectionContent> _rejectionContent = {
  ImageRejectionReason.facesWithoutDestination: _RejectionContent(
    icon: Icons.face_retouching_off_outlined,
    color: Color(0xFFE65100),
    title: 'Human Face Detected',
    description:
        'WanderLens only accepts photos of travel destinations, monuments, '
        'and landscapes — without any people in the frame. Your photo '
        'contains a visible face and cannot be accepted.',
    tips: [
      'Upload a photo with no people visible in it.',
      'Capture the monument, landmark, or scenery on its own.',
      'If someone accidentally appears in the background, try a different angle or crop.',
    ],
  ),
  ImageRejectionReason.notATravelDestination: _RejectionContent(
    icon: Icons.explore_off_outlined,
    color: Color(0xFF1565C0),
    title: 'Not a Travel Destination',
    description:
        'Our AI could not identify this photo as a tourist spot, monument, '
        'or travel-related location. Please make sure your image clearly '
        'shows the place you have entered.',
    tips: [
      'Ensure the location / monument name matches what is in the photo.',
      'Use a clear, well-lit shot of the destination.',
      'Avoid blurry or low-quality images — details help the AI.',
    ],
  ),
  ImageRejectionReason.inappropriateContent: _RejectionContent(
    icon: Icons.block_outlined,
    color: Color(0xFFC62828),
    title: 'Content Policy Violation',
    description:
        'This image contains content that violates WanderLens community '
        'guidelines. Please upload an appropriate travel photo.',
    tips: [
      'Upload only safe, family-friendly travel photos.',
      'Review our Community Guidelines for more details.',
    ],
  ),
  ImageRejectionReason.nonPhotoContent: _RejectionContent(
    icon: Icons.image_not_supported_outlined,
    color: Color(0xFF6A1B9A),
    title: 'Not a Real Photograph',
    description:
        'The image appears to be a screenshot, graphic, logo, or illustration '
        'rather than an actual travel photo.',
    tips: [
      'Upload a real photograph taken at the destination.',
      'Screenshots, posters, and digital artwork are not accepted.',
      'Use JPG or PNG photos taken with a camera or phone.',
    ],
  ),
};

class _RejectionContent {
  const _RejectionContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.tips,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<String> tips;
}

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be logged in to create a post')),
        );
      }
      return;
    }

    // ── Phase 1: Verify with Cloud Vision ───────────────────────────────────
    setState(() => _isVerifying = true);

    ImageVerificationResult verificationResult;
    try {
      verificationResult = await ImageVerificationService.verifyPostImage(
        _selectedImageBytes!,
        _locationController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }

    if (!verificationResult.isApproved) {
      if (mounted) _showRejectionDialog(verificationResult);
      return;
    }

    // ── Phase 2: Upload & save ───────────────────────────────────────────────
    setState(() => _isUploading = true);

    try {
      final uploadedUrl = await CloudinaryService.uploadPostImageFromBytes(
          _selectedImageBytes!);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image. Try again.')),
          );
        }
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

        _captionController.clear();
        _locationController.clear();
        _cityController.clear();
        setState(() {
          _selectedImageBytes = null;
          _privacy = PostPrivacy.public;
        });

        if (MainNavigation.navigationKey.currentState != null) {
          MainNavigation.navigationKey.currentState!.switchTab(0);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showRejectionDialog(ImageVerificationResult result) {
    final content = _rejectionContent[result.rejectionReason] ??
        _rejectionContent[ImageRejectionReason.notATravelDestination]!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Coloured header ──────────────────────────────────────────
            Container(
              color: content.color.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: content.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(content.icon,
                        size: 32, color: content.color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Photo Not Accepted',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: content.color,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.description,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // ── Tips ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: content.color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: content.color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 16, color: content.color),
                            const SizedBox(width: 6),
                            Text(
                              'How to fix this',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: content.color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...content.tips.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: content.color,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(tip,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Actions ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showImagePicker();
                      },
                      icon: const Icon(Icons.photo_library_outlined,
                          size: 16),
                      label: const Text('Choose Another Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: content.color,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isVerifying
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Verifying…',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : TextButton(
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
          ),
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
            labelText: 'Tourist Spot/Location Name/Monument',
            hintText: 'e.g., Badshahi Mosque, Faisal Masjid',
            prefixIcon: Icon(Icons.place_outlined, color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return LocationConstants.pakistanCities.where((String city) {
              return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            _cityController.text = selection;
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text.isEmpty && _cityController.text.isNotEmpty) {
              controller.text = _cityController.text;
            }
            controller.addListener(() {
              _cityController.text = controller.text;
            });

            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              onFieldSubmitted: (value) => onFieldSubmitted(),
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'e.g., Lahore, Karachi, Islamabad',
                prefixIcon: Icon(Icons.location_city_outlined, color: Theme.of(context).colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the city name';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildPrivacyOption(
              PostPrivacy.public,
              Icons.public,
              'Public',
              'Anyone',
            ),
            const SizedBox(width: 8),
            _buildPrivacyOption(
              PostPrivacy.friends,
              Icons.group_outlined,
              'Friends',
              'Friends only',
            ),
            const SizedBox(width: 8),
            _buildPrivacyOption(
              PostPrivacy.private,
              Icons.lock_outline,
              'Only Me',
              'Private',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacyOption(PostPrivacy value, IconData icon, String label, String subtitle) {
    final isSelected = _privacy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _privacy = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIVerificationInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_done_outlined,
              color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Vision AI Review',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Every photo is checked for landmarks, tourist spots, and monuments. '
                  'Selfies without a visible destination and non-travel images are rejected.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withValues(alpha: 0.8),
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
