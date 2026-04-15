import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wanderlens/screens/auth/login_screen.dart';
import 'package:wanderlens/screens/settings/policy_screen.dart';
import 'package:wanderlens/screens/settings/help_support_screen.dart';
import 'package:wanderlens/services/auth_service.dart';
import 'package:wanderlens/services/theme_service.dart';
import 'package:wanderlens/services/user_service.dart';
import '../../responsive/constrained_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Appearance'),
          _buildSettingCard(
            context,
            child: SwitchListTile(
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(themeService.isDarkMode ? "Switch to light mode" : "Switch to dark mode"),
              secondary: Icon(
                themeService.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: colorScheme.primary,
              ),
              value: themeService.isDarkMode,
              onChanged: (bool value) => themeService.toggleTheme(value),
            ),
          ),

          _buildSectionHeader(context, 'Password & Security'),
          _buildSettingCard(
            context,
            child: ListTile(
              leading: Icon(Icons.lock_reset_rounded, color: colorScheme.primary),
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _showChangePasswordSheet(context),
            ),
          ),

          _buildSectionHeader(context, 'Account'),
          _buildSettingCard(
            context,
            child: ListTile(
              leading: Icon(Icons.person_off_outlined, color: colorScheme.error),
              title: Text(
                'Delete account',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.error,
                ),
              ),
              subtitle: const Text(
                'Permanently remove your profile, posts, and data',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.error),
              onTap: () => _onDeleteAccountTapped(context),
            ),
          ),

          _buildSectionHeader(context, 'Support & About'),
          _buildSettingCard(
            context,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.support_agent_rounded, color: colorScheme.primary),
                  title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Message our team', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  ),
                ),
                Divider(height: 1, indent: 55, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Version'),
                  trailing: Text('1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Divider(height: 1, indent: 55, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PolicyScreen(type: PolicyType.terms),
                      ),
                    ),
                ),
                Divider(height: 1, indent: 55, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PolicyScreen(type: PolicyType.privacy),
                      ),
                    ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: child,
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PasswordSheetWidget(),
    );
  }

  Future<void> _onDeleteAccountTapped(BuildContext context) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final wantsContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 10),
            const Expanded(child: Text('Delete account?')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'This permanently deletes your WanderLens account and cannot be undone.\n\n'
            'Your posts, comments, likes, friend connections, wishlist, and notifications '
            'linked to this account will be removed.\n\n'
            'If you use email sign-in, you will need your password on the next step.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (wantsContinue != true || !context.mounted) return;

    final needsPassword = authUser.providerData.any((p) => p.providerId == 'password');
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Final confirmation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  needsPassword
                      ? 'Enter your password to confirm deletion.'
                      : 'Tap Delete to permanently remove your account. If this fails, sign out, sign in again, and retry.',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                if (needsPassword) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setLocal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () {
                if (needsPassword && passwordController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Delete my account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      passwordController.dispose();
      return;
    }

    final password = needsPassword ? passwordController.text : null;
    passwordController.dispose();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: Card(child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting account…'),
            ],
          ),
        ))),
      ),
    );

    try {
      await UserService.deleteAccount(password: password);
      await AuthService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// --- Password Change Sheet with Eye Icons & Logic ---

class PasswordSheetWidget extends StatefulWidget {
  const PasswordSheetWidget({super.key});

  @override
  State<PasswordSheetWidget> createState() => _PasswordSheetWidgetState();
}

class _PasswordSheetWidgetState extends State<PasswordSheetWidget> {
  final _formKey = GlobalKey<FormState>();
  final _curP = TextEditingController();
  final _newP = TextEditingController();
  final _conP = TextEditingController();

  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureCon = true;
  bool _loading = false;

  @override
  void dispose() {
    _curP.dispose(); _newP.dispose(); _conP.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          left: 20, right: 20, top: 15
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
              const Text('Update Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Enter your details to secure your account', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 25),

              // Current Password Field
              _buildField(
                controller: _curP,
                label: 'Current Password',
                isObscured: _obscureCur,
                onToggle: () => setState(() => _obscureCur = !_obscureCur),
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter current password' : null,
              ),
              const SizedBox(height: 16),

              // New Password Field
              _buildField(
                controller: _newP,
                label: 'New Password',
                isObscured: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Password must be at least 8 characters';
                  if (v == _curP.text && v.isNotEmpty) return 'New password cannot be the same as old one';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              _buildField(
                controller: _conP,
                label: 'Confirm New Password',
                isObscured: _obscureCon,
                onToggle: () => setState(() => _obscureCon = !_obscureCon),
                validator: (v) => (v != _newP.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 30),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _update,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      try {
        await UserService.changePassword(_curP.text, _newP.text);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        String msg = e.toString();
        if (msg.contains('wrong-password')) msg = "The current password you entered is incorrect.";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }
}