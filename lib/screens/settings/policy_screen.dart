import 'package:flutter/material.dart';
import '../../responsive/constrained_scaffold.dart';

enum PolicyType { terms, privacy }

class PolicyScreen extends StatelessWidget {
  final PolicyType type;

  const PolicyScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == PolicyType.terms;
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedScaffold(
      appBar: AppBar(
        title: Text(
          isTerms ? 'Terms of Service' : 'Privacy Policy',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTerms ? 'WanderLens Terms of Service' : 'WanderLens Privacy Policy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Last Updated: March 2026',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            if (isTerms) ..._buildTermsContent(colorScheme) else ..._buildPrivacyContent(colorScheme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTermsContent(ColorScheme colorScheme) {
    return [
      _buildSection('1. Acceptance of Terms', 
        'Welcome to WanderLens! By accessing or using our mobile application, you agree to be bound by these Terms of Service. If you do not agree, please do not use the app.'),
      _buildSection('2. User-Generated Content', 
        'WanderLens is a social platform for sharing travel moments. You retain ownership of the content you post, but you grant us a license to display it within the app. Our AI system verifies all images to ensure they meet our travel-only community guidelines.'),
      _buildSection('3. Community Guidelines', 
        'Users must not post inappropriate, offensive, or non-travel related content. Human faces should generally be avoided in primary subjects to maintain the focus on destinations. Violation of these rules may lead to post rejection or account suspension.'),
      _buildSection('4. Account Responsibility', 
        'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.'),
      // _buildSection('5. Limitation of Liability',
      //   'WanderLens is provided "as is". We are not responsible for any travel mishaps, inaccuracies in location data, or content posted by other users.'),
    ];
  }

  List<Widget> _buildPrivacyContent(ColorScheme colorScheme) {
    return [
      _buildSection('1. Information We Collect', 
        'We collect information you provide directly, such as your name, email, bio, and profile picture. We also collect the images  data you upload as travel posts.'),
      _buildSection('2. How We Use Information', 
        'We can use your data to provide social networking features, verify landmark authenticity via AI, manage your wishlist, and improve the overall app experience.'),
      _buildSection('3. Data Storage & Third Parties', 
        'We use Google Firebase for authentication and database management, and Cloudinary for secure image storage. We do not sell your personal information to third parties.'),
      _buildSection('4. Security', 
        'We implement industry-standard security measures to protect your personal information from unauthorized access or disclosure.'),
      _buildSection('5. Your Rights', 
        'You have the right to update your profile information or delete your posts at any time.'),
    ];
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
